import io
import logging
import hmac
import subprocess
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.auth.dependencies import require_roles
from app.auth.dependencies import get_current_user
from app.core.config import get_settings
from app.database.session import get_db
from app.services.inventory_service import find_component_for_stock, get_workspace
from app.services.voice_matching import suggest_components

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Voice Assistant"])


def voice_access(
    request: Request,
    db: Session = Depends(get_db),
    voice_key: str | None = Header(default=None, alias="X-Voice-Key"),
    authorization: str | None = Header(default=None),
):
    configured_key = get_settings().voice_assistant_api_key.strip()
    if configured_key and voice_key and hmac.compare_digest(voice_key, configured_key):
        return None
    return get_current_user(request=request, db=db, authorization=authorization)


class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = "en-US-JennyNeural"


@router.get("/stock")
def get_stock(
    part: str = Query(..., description="Component name, part number, or inventory code"),
    db: Session = Depends(get_db),
    _user=Depends(voice_access),
):
    """
    Lookup component stock and location for the ESP32 Voice Assistant.
    Searches by name, part number, inventory code, and normalized name.
    """
    clean_part = part.strip()
    if not clean_part:
        return {"error": "Invalid or empty part search term."}

    workspace_id = get_workspace(db).id
    comp = find_component_for_stock(db, workspace_id, clean_part)

    if not comp:
        return {"error": f"Part '{clean_part}' not found in inventory.",
                "suggestions": suggest_components(db, workspace_id, clean_part)}

    # Resolve location
    location_parts = []
    if comp.location_id:
        if comp.location:
            location_parts.append(comp.location.display_name)
    if comp.drawer:
        location_parts.append(f"Drawer {comp.drawer}")
    if comp.box:
        location_parts.append(f"Box {comp.box}")

    location_str = ", ".join(location_parts) if location_parts else "Unassigned location"

    # Format quantity (integer if whole, otherwise float)
    qty_val = float(comp.current_quantity)
    formatted_qty = int(qty_val) if qty_val.is_integer() else qty_val

    return {
        "part": comp.name,
        "quantity": formatted_qty,
        "location": location_str,
        "unit": comp.unit,
    }


@router.post("/tts")
async def generate_tts(payload: TTSRequest, _user=Depends(voice_access)):
    """
    Synthesizes speech from text and returns headerless raw 16kHz 16-bit mono PCM.
    This audio stream is played directly via ESP32 I2S DAC (MAX98357A) without decoding.
    """
    text = payload.text.strip()
    if not text:
        return Response(content=b"", media_type="application/octet-stream")

    try:
        import edge_tts

        voice = payload.voice or "en-US-JennyNeural"
        communicate = edge_tts.Communicate(text, voice)
        mp3_buffer = bytearray()

        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                mp3_buffer.extend(chunk["data"])

        if not mp3_buffer:
            logger.warning("edge-tts produced empty audio stream")
            return Response(content=b"", media_type="application/octet-stream")

        # Transcode MP3 to raw 16kHz 16-bit signed little-endian mono PCM via ffmpeg
        proc = subprocess.Popen(
            [
                "ffmpeg",
                "-y",
                "-i",
                "pipe:0",
                "-f",
                "s16le",
                "-acodec",
                "pcm_s16le",
                "-ar",
                "16000",
                "-ac",
                "1",
                "pipe:1",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        pcm_data, _ = proc.communicate(input=bytes(mp3_buffer))

        return Response(
            content=pcm_data,
            media_type="application/octet-stream",
            headers={"Content-Length": str(len(pcm_data))},
        )

    except Exception as e:
        logger.error("TTS generation failed: %s", e, exc_info=True)
        return Response(
            content=b"",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            media_type="application/octet-stream",
        )
