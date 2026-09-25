import csv
from decimal import Decimal
import io
from datetime import datetime, timezone
from html import escape
from pathlib import Path
from typing import Callable

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image as PdfImage,
    LongTable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    TableStyle,
)

from app.models import Component, ComponentImage, Project, ProjectComponent

TECH_PANDA_YOUTUBE_URL = "https://www.youtube.com/@TechPanda-4k"


def _primary_image(component: Component) -> ComponentImage | None:
    return next(
        (image for image in component.images if image.is_primary),
        component.images[0] if component.images else None,
    )


def build_inventory_csv(
    components: list[Component],
    image_url: Callable[[str], str],
) -> str:
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "Image URL",
            "Image Dimensions",
            "Inventory Code",
            "Name",
            "Type",
            "Details",
            "Location",
            "Quantity",
            "Unit",
            "Minimum",
            "Part Number",
            "Manufacturer",
        ]
    )
    for component in components:
        image = _primary_image(component)
        dimensions = (
            f"{image.width} x {image.height} px"
            if image and image.width and image.height
            else ""
        )
        writer.writerow(
            [
                image_url(component.primary_image_preview)
                if component.primary_image_preview
                else "",
                dimensions,
                component.inventory_code,
                component.name,
                component.package_type or "",
                component.description or "",
                component.location_name or "",
                component.current_quantity,
                component.unit,
                component.minimum_quantity,
                component.part_number or "",
                component.manufacturer or "",
            ]
        )
    return output.getvalue()


def _paragraph(value: object, style: ParagraphStyle) -> Paragraph:
    return Paragraph(escape(str(value or "")).replace("\n", "<br/>"), style)


def _pdf_image_cell(
    component: Component,
    body_style: ParagraphStyle,
    image_caption_style: ParagraphStyle,
) -> list[object]:
    image = _primary_image(component)
    if image is None or not Path(image.thumbnail_path).is_file():
        return [_paragraph("No image", image_caption_style)]

    max_width = 18 * mm
    max_height = 18 * mm
    source_width = max(image.width or 1, 1)
    source_height = max(image.height or 1, 1)
    scale = min(max_width / source_width, max_height / source_height)
    try:
        thumbnail = PdfImage(
            image.thumbnail_path,
            width=source_width * scale,
            height=source_height * scale,
            lazy=2,
        )
        thumbnail.hAlign = "CENTER"
    except Exception:
        return [_paragraph("Image unavailable", image_caption_style)]

    dimensions = (
        f"{image.width} x {image.height} px"
        if image.width and image.height
        else "Image"
    )
    return [thumbnail, _paragraph(dimensions, image_caption_style)]


def _draw_pdf_footer(canvas, document) -> None:
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(colors.HexColor("#64748B"))
    canvas.drawString(
        document.leftMargin,
        6 * mm,
        f"Tech Panda Inventory • {TECH_PANDA_YOUTUBE_URL}",
    )
    canvas.drawRightString(
        landscape(A4)[0] - document.rightMargin,
        6 * mm,
        f"Page {document.page}",
    )
    canvas.restoreState()


def build_inventory_pdf(components: list[Component]) -> bytes:
    output = io.BytesIO()
    document = SimpleDocTemplate(
        output,
        pagesize=landscape(A4),
        leftMargin=10 * mm,
        rightMargin=10 * mm,
        topMargin=10 * mm,
        bottomMargin=12 * mm,
        title="Complete Inventory",
        author="Tech Panda Inventory",
    )
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "InventoryTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#0F172A"),
        alignment=TA_LEFT,
        spaceAfter=2 * mm,
    )
    summary_style = ParagraphStyle(
        "InventorySummary",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#475569"),
        spaceAfter=4 * mm,
    )
    header_style = ParagraphStyle(
        "InventoryHeader",
        parent=styles["BodyText"],
        fontName="Helvetica-Bold",
        fontSize=7,
        leading=8,
        textColor=colors.white,
        alignment=TA_CENTER,
    )
    body_style = ParagraphStyle(
        "InventoryBody",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=7,
        leading=8.5,
        textColor=colors.HexColor("#0F172A"),
        alignment=TA_LEFT,
    )
    image_caption_style = ParagraphStyle(
        "InventoryImageCaption",
        parent=body_style,
        fontSize=5.5,
        leading=6.5,
        textColor=colors.HexColor("#64748B"),
        alignment=TA_CENTER,
        spaceBefore=1,
    )

    story: list[object] = [
        Paragraph("Complete Inventory", title_style),
        Paragraph(
            (
                f"Generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}"
                f" &nbsp;&bull;&nbsp; {len(components)} component"
                f"{'' if len(components) == 1 else 's'}"
                f" &nbsp;&bull;&nbsp; {escape(TECH_PANDA_YOUTUBE_URL)}"
            ),
            summary_style,
        ),
        Spacer(1, 1 * mm),
    ]
    headers = [
        "Image",
        "Code",
        "Component",
        "Type",
        "Details",
        "Location",
        "Qty",
        "Unit",
        "Minimum",
        "Part number",
        "Manufacturer",
    ]
    table_data: list[list[object]] = [
        [_paragraph(header, header_style) for header in headers]
    ]
    for component in components:
        table_data.append(
            [
                _pdf_image_cell(component, body_style, image_caption_style),
                _paragraph(component.inventory_code, body_style),
                _paragraph(component.name, body_style),
                _paragraph(component.package_type or "", body_style),
                _paragraph(component.description or "", body_style),
                _paragraph(component.location_name or "", body_style),
                _paragraph(component.current_quantity, body_style),
                _paragraph(component.unit, body_style),
                _paragraph(component.minimum_quantity, body_style),
                _paragraph(component.part_number or "", body_style),
                _paragraph(component.manufacturer or "", body_style),
            ]
        )

    table = LongTable(
        table_data,
        colWidths=[
            22 * mm,
            22 * mm,
            32 * mm,
            21 * mm,
            38 * mm,
            27 * mm,
            15 * mm,
            16 * mm,
            15 * mm,
            26 * mm,
            28 * mm,
        ],
        repeatRows=1,
        hAlign="LEFT",
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F766E")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (0, 0), (0, -1), "CENTER"),
                ("ALIGN", (6, 1), (8, -1), "RIGHT"),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [colors.white, colors.HexColor("#F8FAFC")],
                ),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#CBD5E1")),
            ]
        )
    )
    story.append(table)
    document.build(
        story,
        onFirstPage=_draw_pdf_footer,
        onLaterPages=_draw_pdf_footer,
    )
    return output.getvalue()


def build_project_pdf(
    project: Project,
    project_components: list[ProjectComponent],
) -> bytes:
    output = io.BytesIO()
    document = SimpleDocTemplate(
        output,
        pagesize=landscape(A4),
        leftMargin=10 * mm,
        rightMargin=10 * mm,
        topMargin=10 * mm,
        bottomMargin=12 * mm,
        title=project.name,
        author="Tech Panda Inventory",
    )
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "ProjectTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#0F172A"),
        alignment=TA_LEFT,
        spaceAfter=2 * mm,
    )
    summary_style = ParagraphStyle(
        "ProjectSummary",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#475569"),
        spaceAfter=3 * mm,
    )
    section_style = ParagraphStyle(
        "ProjectSection",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=12,
        textColor=colors.HexColor("#0F766E"),
        spaceAfter=1.5 * mm,
    )
    description_style = ParagraphStyle(
        "ProjectDescription",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#0F172A"),
        borderColor=colors.HexColor("#CBD5E1"),
        borderWidth=0.5,
        borderPadding=6,
        backColor=colors.HexColor("#F8FAFC"),
        spaceAfter=4 * mm,
    )
    header_style = ParagraphStyle(
        "ProjectTableHeader",
        parent=styles["BodyText"],
        fontName="Helvetica-Bold",
        fontSize=7,
        leading=8,
        textColor=colors.white,
        alignment=TA_CENTER,
    )
    body_style = ParagraphStyle(
        "ProjectTableBody",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=7,
        leading=8.5,
        textColor=colors.HexColor("#0F172A"),
        alignment=TA_LEFT,
    )
    image_caption_style = ParagraphStyle(
        "ProjectImageCaption",
        parent=body_style,
        fontSize=5.5,
        leading=6.5,
        textColor=colors.HexColor("#64748B"),
        alignment=TA_CENTER,
        spaceBefore=1,
    )

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    total_cost_str = f" &nbsp;&bull;&nbsp; Total Cost: ${project.total_cost:.2f}" if project.total_cost > 0 else ""
    story: list[object] = [
        _paragraph(project.name, title_style),
        Paragraph(
            (
                f"{escape(project.project_type)} &nbsp;&bull;&nbsp; "
                f"{escape(project.status)} &nbsp;&bull;&nbsp; "
                f"Generated {generated_at} &nbsp;&bull;&nbsp; "
                f"{len(project_components)} component"
                f"{'' if len(project_components) == 1 else 's'}"
                f"{total_cost_str}"
                f" &nbsp;&bull;&nbsp; {escape(TECH_PANDA_YOUTUBE_URL)}"
            ),
            summary_style,
        ),
        Paragraph("Project description", section_style),
        _paragraph(project.description or "No project description provided.", description_style),
        Paragraph("Project components", section_style),
    ]

    if not project_components:
        story.append(_paragraph("No components have been added to this project.", body_style))
    else:
        headers = [
            "Image",
            "Code",
            "Component",
            "Type",
            "Component details",
            "Location",
            "Qty",
            "Unit",
            "Unit Price",
            "Line Cost",
            "Project notes",
        ]
        table_data: list[list[object]] = [
            [_paragraph(header, header_style) for header in headers]
        ]
        for line in project_components:
            component = line.component
            unit_price_str = f"${component.price:.2f}" if component.price is not None else "—"
            line_cost_str = (
                f"${(Decimal(str(line.quantity)) * Decimal(str(component.price))):.2f}"
                if component.price is not None
                else "—"
            )
            table_data.append(
                [
                    _pdf_image_cell(component, body_style, image_caption_style),
                    _paragraph(component.inventory_code, body_style),
                    _paragraph(component.name, body_style),
                    _paragraph(component.package_type or "", body_style),
                    _paragraph(component.description or "", body_style),
                    _paragraph(component.location_name or "", body_style),
                    _paragraph(line.quantity, body_style),
                    _paragraph(line.unit, body_style),
                    _paragraph(unit_price_str, body_style),
                    _paragraph(line_cost_str, body_style),
                    _paragraph(line.notes or "", body_style),
                ]
            )

        table = LongTable(
            table_data,
            colWidths=[
                22 * mm,
                22 * mm,
                20 * mm,
                20 * mm,
                30 * mm,
                20 * mm,
                38 * mm,
                24 * mm,
                14 * mm,
                14 * mm,
                18 * mm,
                20 * mm,
                34 * mm,
                23 * mm,
                48 * mm,
                28 * mm,
                17 * mm,
                18 * mm,
                40 * mm,
            ],
            repeatRows=1,
            hAlign="LEFT",
        )
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F766E")),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                    ("ALIGN", (0, 0), (0, -1), "CENTER"),
                    ("ALIGN", (6, 1), (6, -1), "RIGHT"),
                    ("ALIGN", (8, 1), (9, -1), "RIGHT"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 3),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                    (
                        "ROWBACKGROUNDS",
                        (0, 1),
                        (-1, -1),
                        [colors.white, colors.HexColor("#F8FAFC")],
                    ),
                    ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#CBD5E1")),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
                ]
            )
        )
        story.append(table)
        if project.total_cost > 0:
            cost_summary_style = ParagraphStyle(
                "CostSummaryStyle",
                parent=body_style,
                fontName="Helvetica-Bold",
                fontSize=11,
                leading=14,
                textColor=colors.HexColor("#0F766E"),
                alignment=2,  # right-aligned
            )
            story.append(Spacer(1, 4 * mm))
            story.append(Paragraph(f"Total Project Cost: ${project.total_cost:.2f}", cost_summary_style))

    document.build(
        story,
        onFirstPage=_draw_pdf_footer,
        onLaterPages=_draw_pdf_footer,
    )
    return output.getvalue()
