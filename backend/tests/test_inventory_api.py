import csv
from decimal import Decimal
import io
import os
from base64 import b64decode
from uuid import uuid4

os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["ADMIN_NAME"] = "admin"
os.environ["ADMIN_EMAIL"] = ""
os.environ["ADMIN_PASSWORD"] = "admin"
os.environ["ENVIRONMENT"] = "test"

from fastapi.testclient import TestClient

from app.api.auth import normalize_login
from app.main import app


def auth_headers(test_client: TestClient) -> dict[str, str]:
    response = test_client.post("/api/v1/auth/login", json={"username": "admin", "password": "admin"})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_health_ready() -> None:
    with TestClient(app) as test_client:
        response = test_client.get("/api/v1/health/ready")
        assert response.status_code == 200


def test_username_only_login_uses_default_domain() -> None:
    assert normalize_login("admin") == "admin"
    assert normalize_login(" Admin ") == "admin"


def test_create_component_with_opening_stock_and_duplicate_transaction() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        categories = test_client.get("/api/v1/categories", headers=headers).json()
        resistor = next(item for item in categories if item["name"] == "Resistors")
        created = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "1K Resistor",
                "category_id": resistor["id"],
                "opening_quantity": "100",
                "minimum_quantity": "20",
                "unit": "Pieces",
                "specifications": {"Resistance": "1 kΩ", "Tolerance": "5%"},
            },
        )
        assert created.status_code == 200, created.text
        component = created.json()
        assert component["inventory_code"].startswith("RES-")
        assert component["current_quantity"] == "100.0000"

        key = str(uuid4())
        payload = {"transaction_type": "stock_out", "idempotency_key": key, "lines": [{"component_id": component["id"], "quantity": "5"}]}
        first = test_client.post("/api/v1/transactions", headers=headers, json=payload)
        second = test_client.post("/api/v1/transactions", headers=headers, json=payload)
        assert first.status_code == 200, first.text
        assert second.status_code == 200, second.text
        assert first.json()["id"] == second.json()["id"]

        refreshed = test_client.get(f"/api/v1/components/{component['id']}", headers=headers)
        assert refreshed.json()["current_quantity"] == "95.0000"


def test_component_code_uses_component_type_prefix() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        transistor = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "BC547 transistor",
                "category_id": category["id"],
                "package_type": "Transistor",
            },
        )
        assert transistor.status_code == 200, transistor.text
        assert transistor.json()["inventory_code"].startswith("TRA-")

        other = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Miscellaneous item",
                "category_id": category["id"],
                "package_type": "Other",
            },
        )
        assert other.status_code == 200, other.text
        assert other.json()["inventory_code"].startswith("OTH-")


def test_duplicate_component_create_is_rejected() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        payload = {
            "name": "Touch Sensor HW-139 Module",
            "category_id": category["id"],
            "package_type": "Sensor Modules",
            "manufacturer": "Generic",
        }
        first = test_client.post("/api/v1/components", headers=headers, json=payload)
        duplicate = test_client.post("/api/v1/components", headers=headers, json=payload)

        assert first.status_code == 200, first.text
        assert duplicate.status_code == 409
        assert "already exists" in duplicate.json()["detail"]


def test_dashboard_component_type_stock_cards() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        categories = test_client.get("/api/v1/categories", headers=headers).json()
        category = categories[0]
        active_type_count = len(test_client.get("/api/v1/component-types", headers=headers).json())

        sensor = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Dashboard stocked sensor",
                "category_id": category["id"],
                "package_type": "Dashboard Sensor",
                "opening_quantity": "7",
            },
        )
        empty = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Dashboard empty sensor",
                "category_id": category["id"],
                "package_type": "Dashboard Empty",
                "opening_quantity": "0",
            },
        )
        assert sensor.status_code == 200, sensor.text
        assert empty.status_code == 200, empty.text

        dashboard = test_client.get("/api/v1/dashboard", headers=headers)
        assert dashboard.status_code == 200
        body = dashboard.json()
        assert body["total_component_types"] == active_type_count
        assert body["total_products"] == len(
            test_client.get("/api/v1/components", headers=headers).json()
        )

        cards = body["component_type_stock"]
        stocked = next(item for item in cards if item["name"] == "Dashboard Sensor")
        assert stocked["product_count"] == 1
        assert stocked["stock_quantity"] == "7.0000"
        assert all(item["name"] != "Dashboard Empty" for item in cards)


def test_atomic_insufficient_stock_failure() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={"name": "DHT22 Sensor", "category_id": category["id"], "opening_quantity": "5", "unit": "Pieces"},
        ).json()
        failed = test_client.post(
            "/api/v1/transactions",
            headers=headers,
            json={"transaction_type": "stock_out", "idempotency_key": str(uuid4()), "lines": [{"component_id": component["id"], "quantity": "100"}]},
        )
        assert failed.status_code == 409
        refreshed = test_client.get(f"/api/v1/components/{component['id']}", headers=headers)
        assert refreshed.json()["current_quantity"] == "5.0000"


def test_edit_and_delete_entire_stock_movement_reconciles_inventory() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        first = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Editable movement first component",
                "category_id": category["id"],
                "opening_quantity": "10",
            },
        ).json()
        second = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Editable movement second component",
                "category_id": category["id"],
                "opening_quantity": "8",
            },
        ).json()
        created = test_client.post(
            "/api/v1/transactions",
            headers=headers,
            json={
                "transaction_type": "stock_out",
                "idempotency_key": str(uuid4()),
                "reason": "Editable movement",
                "lines": [{"component_id": first["id"], "quantity": "3"}],
            },
        )
        assert created.status_code == 200, created.text
        transaction_id = created.json()["id"]

        detail = test_client.get(
            f"/api/v1/transactions/{transaction_id}",
            headers=headers,
        )
        assert detail.status_code == 200, detail.text
        assert detail.json()["can_modify"] is True
        assert detail.json()["lines"][0]["component_name"] == first["name"]
        assert detail.json()["lines"][0]["quantity"] == "3.0000"

        updated = test_client.put(
            f"/api/v1/transactions/{transaction_id}",
            headers=headers,
            json={
                "transaction_type": "stock_out",
                "reason": "Moved to second component",
                "lines": [{"component_id": second["id"], "quantity": "2"}],
            },
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["id"] == transaction_id
        assert updated.json()["reason"] == "Moved to second component"
        assert updated.json()["lines"][0]["component_id"] == second["id"]
        assert test_client.get(
            f"/api/v1/components/{first['id']}",
            headers=headers,
        ).json()["current_quantity"] == "10.0000"
        assert test_client.get(
            f"/api/v1/components/{second['id']}",
            headers=headers,
        ).json()["current_quantity"] == "6.0000"

        deleted = test_client.delete(
            f"/api/v1/transactions/{transaction_id}",
            headers=headers,
        )
        assert deleted.status_code == 204, deleted.text
        assert test_client.get(
            f"/api/v1/components/{second['id']}",
            headers=headers,
        ).json()["current_quantity"] == "8.0000"
        assert test_client.get(
            f"/api/v1/transactions/{transaction_id}",
            headers=headers,
        ).status_code == 404


def test_deleting_consumed_stock_in_movement_is_rejected() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Consumed stock-in movement",
                "category_id": category["id"],
                "opening_quantity": "5",
            },
        ).json()
        stock_out = test_client.post(
            "/api/v1/transactions",
            headers=headers,
            json={
                "transaction_type": "stock_out",
                "idempotency_key": str(uuid4()),
                "lines": [{"component_id": component["id"], "quantity": "4"}],
            },
        )
        assert stock_out.status_code == 200, stock_out.text

        opening_id = None
        for transaction in test_client.get(
            "/api/v1/transactions",
            headers=headers,
        ).json():
            if transaction["transaction_type"] != "stock_in":
                continue
            detail = test_client.get(
                f"/api/v1/transactions/{transaction['id']}",
                headers=headers,
            ).json()
            if any(
                line["component_id"] == component["id"]
                for line in detail["lines"]
            ):
                opening_id = transaction["id"]
                break
        assert opening_id is not None

        failed = test_client.delete(
            f"/api/v1/transactions/{opening_id}",
            headers=headers,
        )
        assert failed.status_code == 409
        assert "no longer has enough stock" in failed.json()["detail"]
        assert test_client.get(
            f"/api/v1/components/{component['id']}",
            headers=headers,
        ).json()["current_quantity"] == "1.0000"


def test_new_movement_code_does_not_collide_after_deleting_older_movement() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Movement code gap component",
                "category_id": category["id"],
                "opening_quantity": "30",
            },
        ).json()

        def stock_out() -> object:
            return test_client.post(
                "/api/v1/transactions",
                headers=headers,
                json={
                    "transaction_type": "stock_out",
                    "idempotency_key": str(uuid4()),
                    "lines": [{"component_id": component["id"], "quantity": "1"}],
                },
            )

        first = stock_out()
        second = stock_out()
        assert first.status_code == 200, first.text
        assert second.status_code == 200, second.text
        assert test_client.delete(
            f"/api/v1/transactions/{first.json()['id']}",
            headers=headers,
        ).status_code == 204

        after_gap = stock_out()
        assert after_gap.status_code == 200, after_gap.text
        second_number = int(second.json()["transaction_code"].split("-")[-1])
        after_gap_number = int(
            after_gap.json()["transaction_code"].split("-")[-1]
        )
        assert after_gap_number > second_number


def test_project_components_consume_edit_and_return_inventory() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Project allocation resistor",
                "category_id": category["id"],
                "opening_quantity": "10",
                "unit": "Pieces",
            },
        ).json()
        project = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Inventory consuming project"},
            json={"name": "Inventory consuming project", "status": "In Progress"},
        ).json()
        path = f"/api/v1/projects/{project['id']}/components/{component['id']}"

        added = test_client.put(path, headers=headers, json={"quantity": "3"})
        assert added.status_code == 200, added.text
        assert added.json()["quantity"] == "3.0000"
        assert added.json()["component_name"] == component["name"]
        assert added.json()["available_quantity"] == "7.0000"

        listed = test_client.get(
            f"/api/v1/projects/{project['id']}/components",
            headers=headers,
        )
        assert listed.status_code == 200
        assert [item["component_id"] for item in listed.json()] == [component["id"]]
        protected_component = test_client.get(
            f"/api/v1/components/{component['id']}",
            headers=headers,
        )
        assert protected_component.json()["can_delete"] is False

        project_movement = next(
            item
            for item in test_client.get(
                "/api/v1/transactions",
                headers=headers,
            ).json()
            if item["project_id"] == project["id"]
        )
        assert project_movement["can_modify"] is False
        protected_delete = test_client.delete(
            f"/api/v1/transactions/{project_movement['id']}",
            headers=headers,
        )
        assert protected_delete.status_code == 409
        assert "managed from their project" in protected_delete.json()["detail"]

        increased = test_client.put(path, headers=headers, json={"quantity": "5"})
        assert increased.status_code == 200, increased.text
        assert increased.json()["available_quantity"] == "5.0000"

        archive_in_use = test_client.delete(
            f"/api/v1/components/{component['id']}",
            headers=headers,
        )
        assert archive_in_use.status_code == 409
        assert "used by a project" in archive_in_use.json()["detail"]

        decreased = test_client.put(path, headers=headers, json={"quantity": "2"})
        assert decreased.status_code == 200, decreased.text
        assert decreased.json()["available_quantity"] == "8.0000"

        removed = test_client.delete(path, headers=headers)
        assert removed.status_code == 204, removed.text
        assert test_client.get(
            f"/api/v1/projects/{project['id']}/components",
            headers=headers,
        ).json() == []
        refreshed = test_client.get(
            f"/api/v1/components/{component['id']}",
            headers=headers,
        )
        assert refreshed.json()["current_quantity"] == "10.0000"


def test_project_component_insufficient_stock_keeps_previous_quantity() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Limited project component",
                "category_id": category["id"],
                "opening_quantity": "4",
            },
        ).json()
        project = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Limited stock project"},
            json={"name": "Limited stock project", "status": "In Progress"},
        ).json()
        path = f"/api/v1/projects/{project['id']}/components/{component['id']}"
        assert test_client.put(path, headers=headers, json={"quantity": "2"}).status_code == 200

        failed = test_client.put(path, headers=headers, json={"quantity": "20"})
        assert failed.status_code == 409
        lines = test_client.get(
            f"/api/v1/projects/{project['id']}/components",
            headers=headers,
        ).json()
        assert lines[0]["quantity"] == "2.0000"
        refreshed = test_client.get(
            f"/api/v1/components/{component['id']}",
            headers=headers,
        )
        assert refreshed.json()["current_quantity"] == "2.0000"


def test_batch_project_component_save_is_atomic_and_reconciles_all_lines() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        first = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Batch project first component",
                "category_id": category["id"],
                "opening_quantity": "10",
            },
        ).json()
        second = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Batch project second component",
                "category_id": category["id"],
                "opening_quantity": "4",
            },
        ).json()
        project = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Batch component project"},
            json={"name": "Batch component project", "status": "In Progress"},
        ).json()
        path = f"/api/v1/projects/{project['id']}/components"

        added = test_client.put(
            path,
            headers=headers,
            json={
                "lines": [
                    {"component_id": first["id"], "quantity": "3"},
                    {"component_id": second["id"], "quantity": "1"},
                ]
            },
        )
        assert added.status_code == 200, added.text
        assert {
            item["component_id"]: item["quantity"] for item in added.json()
        } == {first["id"]: "3.0000", second["id"]: "1.0000"}

        changed = test_client.put(
            path,
            headers=headers,
            json={"lines": [{"component_id": first["id"], "quantity": "5"}]},
        )
        assert changed.status_code == 200, changed.text
        assert [item["component_id"] for item in changed.json()] == [first["id"]]
        assert test_client.get(
            f"/api/v1/components/{first['id']}",
            headers=headers,
        ).json()["current_quantity"] == "5.0000"
        assert test_client.get(
            f"/api/v1/components/{second['id']}",
            headers=headers,
        ).json()["current_quantity"] == "4.0000"

        failed = test_client.put(
            path,
            headers=headers,
            json={
                "lines": [
                    {"component_id": first["id"], "quantity": "20"},
                    {"component_id": second["id"], "quantity": "2"},
                ]
            },
        )
        assert failed.status_code == 409
        unchanged = test_client.get(path, headers=headers).json()
        assert [(item["component_id"], item["quantity"]) for item in unchanged] == [
            (first["id"], "5.0000")
        ]
        assert test_client.get(
            f"/api/v1/components/{second['id']}",
            headers=headers,
        ).json()["current_quantity"] == "4.0000"


def test_update_component_name_type_and_details() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        created = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Generic part",
                "category_id": category["id"],
                "package_type": "Module",
                "description": "Old details",
            },
        )
        assert created.status_code == 200, created.text
        component = created.json()

        updated = test_client.patch(
            f"/api/v1/components/{component['id']}",
            headers=headers,
            json={
                "name": "BC547 NPN Transistor",
                "manufacturer": "STMicroelectronics",
                "package_type": "Transistor",
                "unit": "Pieces",
                "description": "General purpose NPN transistor for switching and amplification.",
            },
        )
        assert updated.status_code == 200, updated.text
        body = updated.json()
        assert body["name"] == "BC547 NPN Transistor"
        assert body["manufacturer"] == "STMicroelectronics"
        assert body["package_type"] == "Transistor"
        assert body["unit"] == "Pieces"
        assert "switching" in body["description"]

        found = test_client.get("/api/v1/components?q=amplification", headers=headers)
        assert any(item["id"] == component["id"] for item in found.json())


def test_delete_component_archives_and_hides_component() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        created = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Temporary delete target",
                "category_id": category["id"],
                "opening_quantity": "0",
                "unit": "Pieces",
            },
        )
        assert created.status_code == 200, created.text
        component = created.json()

        deleted = test_client.delete(f"/api/v1/components/{component['id']}", headers=headers)
        assert deleted.status_code == 204, deleted.text

        listed = test_client.get("/api/v1/components?q=Temporary", headers=headers)
        assert listed.status_code == 200
        assert all(item["id"] != component["id"] for item in listed.json())

        fetched = test_client.get(f"/api/v1/components/{component['id']}", headers=headers)
        assert fetched.status_code == 404

        stock_out = test_client.post(
            "/api/v1/transactions",
            headers=headers,
            json={
                "transaction_type": "stock_out",
                "idempotency_key": str(uuid4()),
                "lines": [{"component_id": component["id"], "quantity": "1"}],
            },
        )
        assert stock_out.status_code == 404


def test_component_with_stock_movement_cannot_be_deleted() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        created = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Protected transaction component",
                "category_id": category["id"],
                "opening_quantity": "2",
            },
        )
        assert created.status_code == 200, created.text
        component = created.json()
        assert component["can_delete"] is False

        deleted = test_client.delete(
            f"/api/v1/components/{component['id']}",
            headers=headers,
        )
        assert deleted.status_code == 409
        assert "stock movement history" in deleted.json()["detail"]
        listed = test_client.get(
            "/api/v1/components?q=Protected transaction",
            headers=headers,
        )
        assert listed.status_code == 200
        assert listed.json()[0]["can_delete"] is False


def test_optional_component_image_upload() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={"name": "PLA Filament", "category_id": category["id"], "unit": "Kilograms", "manufacturer": "Generic"},
        ).json()
        tiny_png = b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")
        uploaded = test_client.post(
            f"/api/v1/components/{component['id']}/images",
            headers=headers,
            files={"upload": ("filament.png", tiny_png, "application/octet-stream")},
        )
        assert uploaded.status_code == 200, uploaded.text
        assert uploaded.json()["thumbnail"].startswith("/api/v1/media/thumbnails/")

        images = test_client.get(f"/api/v1/components/{component['id']}/images", headers=headers)
        assert images.status_code == 200
        assert len(images.json()) == 1

        refreshed = test_client.get(f"/api/v1/components/{component['id']}", headers=headers)
        assert refreshed.json()["primary_image_thumbnail"].startswith("/api/v1/media/thumbnails/")
        assert refreshed.json()["primary_image_preview"].startswith("/api/v1/media/previews/")


def test_component_image_upload_replaces_existing_image() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={"name": "Replaceable Image", "category_id": category["id"]},
        ).json()
        tiny_png = b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")

        first = test_client.post(
            f"/api/v1/components/{component['id']}/images",
            headers=headers,
            files={"upload": ("first.png", tiny_png, "image/png")},
        )
        assert first.status_code == 200, first.text

        second = test_client.post(
            f"/api/v1/components/{component['id']}/images",
            headers=headers,
            files={"upload": ("replacement.png", tiny_png, "image/png")},
        )
        assert second.status_code == 200, second.text

        images = test_client.get(
            f"/api/v1/components/{component['id']}/images",
            headers=headers,
        )
        assert images.status_code == 200
        assert images.json() == [second.json()]
        assert images.json()[0]["filename"] == "replacement.png"
        assert images.json()[0]["id"] != first.json()["id"]


def test_csv_and_pdf_inventory_exports_include_image_information() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Exportable Photo Component",
                "category_id": category["id"],
                "package_type": "Module",
                "opening_quantity": "4",
                "unit": "Pieces",
            },
        ).json()
        tiny_png = b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        )
        uploaded = test_client.post(
            f"/api/v1/components/{component['id']}/images",
            headers=headers,
            files={"upload": ("export-photo.png", tiny_png, "image/png")},
        )
        assert uploaded.status_code == 200, uploaded.text

        export_headers = {
            **headers,
            "x-forwarded-proto": "https",
            "x-forwarded-host": "inventory.example.test",
        }
        csv_export = test_client.get(
            "/api/v1/reports/inventory.csv",
            headers=export_headers,
        )
        assert csv_export.status_code == 200, csv_export.text
        assert csv_export.headers["content-type"].startswith("text/csv")
        rows = list(csv.DictReader(io.StringIO(csv_export.content.decode("utf-8-sig"))))
        exported_component = next(
            row for row in rows if row["Name"] == "Exportable Photo Component"
        )
        assert exported_component["Image URL"].startswith(
            "https://inventory.example.test/api/v1/media/previews/"
        )
        assert exported_component["Image Dimensions"] == "1 x 1 px"
        assert exported_component["Quantity"] == "4.0000"

        pdf_export = test_client.get(
            "/api/v1/reports/inventory.pdf",
            headers=headers,
        )
        assert pdf_export.status_code == 200, pdf_export.text
        assert pdf_export.headers["content-type"] == "application/pdf"
        assert pdf_export.headers["content-disposition"] == (
            "attachment; filename=inventory.pdf"
        )
        assert pdf_export.content.startswith(b"%PDF-")
        assert len(pdf_export.content) > 1_000


def test_project_description_update_and_pdf_export() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Project PDF Controller",
                "category_id": category["id"],
                "package_type": "Controller",
                "description": "Controls the lighting sequence.",
                "opening_quantity": "5",
                "unit": "Pieces",
            },
        ).json()
        created = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={
                "name": "Studio Light Build",
                "description": "Original project description.",
            },
        )
        assert created.status_code == 200, created.text
        project = created.json()
        assert project["description"] == "Original project description."

        updated = test_client.patch(
            f"/api/v1/projects/{project['id']}",
            headers=headers,
            json={"description": "Build notes for the studio lighting project."},
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["description"] == (
            "Build notes for the studio lighting project."
        )
        listed_project = next(
            item
            for item in test_client.get("/api/v1/projects", headers=headers).json()
            if item["id"] == project["id"]
        )
        assert listed_project["description"] == updated.json()["description"]

        assigned = test_client.put(
            f"/api/v1/projects/{project['id']}/components/{component['id']}",
            headers=headers,
            json={"quantity": "2", "notes": "Use on the main controller board."},
        )
        assert assigned.status_code == 200, assigned.text

        pdf_export = test_client.get(
            f"/api/v1/projects/{project['id']}/report.pdf",
            headers=headers,
        )
        assert pdf_export.status_code == 200, pdf_export.text
        assert pdf_export.headers["content-type"] == "application/pdf"
        assert pdf_export.headers["content-disposition"] == (
            "attachment; filename=Studio-Light-Build.pdf"
        )
        assert pdf_export.content.startswith(b"%PDF-")
        assert len(pdf_export.content) > 1_000


def test_project_image_upload_replaces_previous_image() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        project = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Project With Image"},
        ).json()
        tiny_png = b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        )

        first = test_client.post(
            f"/api/v1/projects/{project['id']}/image",
            headers=headers,
            files={"upload": ("project-first.png", tiny_png, "image/png")},
        )
        assert first.status_code == 200, first.text
        first_url = first.json()["image_url"]
        assert first_url.startswith("/api/v1/media/projects/")
        first_image = test_client.get(first_url)
        assert first_image.status_code == 200
        assert first_image.headers["content-type"] == "image/jpeg"

        second = test_client.post(
            f"/api/v1/projects/{project['id']}/image",
            headers=headers,
            files={"upload": ("project-second.png", tiny_png, "image/png")},
        )
        assert second.status_code == 200, second.text
        assert second.json()["image_url"] != first_url
        assert test_client.get(first_url).status_code == 404
        listed = next(
            item
            for item in test_client.get("/api/v1/projects", headers=headers).json()
            if item["id"] == project["id"]
        )
        assert listed["image_url"] == second.json()["image_url"]


def test_component_type_management_and_location_assignment() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        icon_svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M4 4h16v16H4z"/></svg>'
        created_type = test_client.post(
            "/api/v1/component-types",
            headers=headers,
            json={"name": "RF Module", "icon_svg": icon_svg},
        )
        assert created_type.status_code == 200, created_type.text
        assert created_type.json()["icon_svg"] == icon_svg
        renamed_type = test_client.patch(f"/api/v1/component-types/{created_type.json()['id']}", headers=headers, json={"name": "Wireless Module"})
        assert renamed_type.status_code == 200
        assert renamed_type.json()["name"] == "Wireless Module"
        assert renamed_type.json()["icon_svg"] == icon_svg

        location = test_client.post(
            "/api/v1/locations",
            headers=headers,
            json={"name": "Parts Room", "cabinet": "A", "shelf": "2", "drawer": "D4", "box": "B7", "bin": "3"},
        )
        assert location.status_code == 200, location.text
        assert location.json()["display_name"] == "Parts Room / A / 2 / D4 / B7 / 3"

        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        component = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "ESP32 Wireless",
                "category_id": category["id"],
                "package_type": "Wireless Module",
                "location_id": location.json()["id"],
            },
        )
        assert component.status_code == 200, component.text
        assert component.json()["location_name"] == "Parts Room / A / 2 / D4 / B7 / 3"

        updated_location = test_client.patch(f"/api/v1/locations/{location.json()['id']}", headers=headers, json={"shelf": "3"})
        assert updated_location.status_code == 200
        refreshed = test_client.get(f"/api/v1/components/{component.json()['id']}", headers=headers)
        assert "/ 3 / D4" in refreshed.json()["location_name"]


def test_component_price_lifecycle() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]

        # 1. Create component with a price
        created = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Priced Component LM317",
                "category_id": category["id"],
                "package_type": "Voltage Regulator",
                "price": "12.50",
            },
        )
        assert created.status_code == 200, created.text
        component_id = created.json()["id"]
        assert created.json()["price"] == "12.5000"

        # 2. Get component and verify price
        retrieved = test_client.get(f"/api/v1/components/{component_id}", headers=headers)
        assert retrieved.status_code == 200
        assert retrieved.json()["price"] == "12.5000"

        # 3. Edit component price
        updated = test_client.patch(
            f"/api/v1/components/{component_id}",
            headers=headers,
            json={"price": "18.75"},
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["price"] == "18.7500"

        # 4. Clear component price
        cleared = test_client.patch(
            f"/api/v1/components/{component_id}",
            headers=headers,
            json={"price": None},
        )
        assert cleared.status_code == 200, cleared.text
        assert cleared.json()["price"] is None


def test_location_qr_code_lifecycle() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)

        # 1. Create location with generate_qr_code = True
        created = test_client.post(
            "/api/v1/locations",
            headers=headers,
            json={
                "name": "QR Tested Cabinet",
                "cabinet": "C1",
                "shelf": "S2",
                "generate_qr_code": True,
            },
        )
        assert created.status_code == 200, created.text
        loc_data = created.json()
        assert loc_data["qr_code_value"] == f"location:{loc_data['id']}"

        # 2. Query location by qr_code_value
        found = test_client.get(
            "/api/v1/locations",
            headers=headers,
            params={"qr_code_value": f"location:{loc_data['id']}"},
        )
        assert found.status_code == 200
        assert len(found.json()) >= 1
        assert found.json()[0]["id"] == loc_data["id"]

        # 3. Update location - disable QR code
        updated = test_client.patch(
            f"/api/v1/locations/{loc_data['id']}",
            headers=headers,
            json={"generate_qr_code": False},
        )
        assert updated.status_code == 200
        assert updated.json()["qr_code_value"] is None

        # 4. Re-enable QR code
        re_enabled = test_client.patch(
            f"/api/v1/locations/{loc_data['id']}",
            headers=headers,
            json={"generate_qr_code": True},
        )
        assert re_enabled.status_code == 200
        assert re_enabled.json()["qr_code_value"] == f"location:{loc_data['id']}"


def test_component_datasheet_and_expiry_lifecycle() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]

        # 1. Create component with datasheet_text and expiry_date
        created = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "18650 Li-Ion Battery 3.7V",
                "category_id": category["id"],
                "opening_quantity": "10",
                "minimum_quantity": "2",
                "unit": "Pieces",
                "datasheet_text": "Nominal Voltage: 3.7V\nCapacity: 2600mAh\nCharge Cutoff: 4.2V",
                "expiry_date": "2028-06-30",
            },
        )
        assert created.status_code == 200, created.text
        component = created.json()
        assert component["datasheet_text"] == "Nominal Voltage: 3.7V\nCapacity: 2600mAh\nCharge Cutoff: 4.2V"
        assert component["expiry_date"] == "2028-06-30"
        assert component["datasheet_url"] is None

        # 2. Upload datasheet document (PDF)
        upload_res = test_client.post(
            f"/api/v1/components/{component['id']}/datasheet",
            headers=headers,
            files={"upload": ("spec_sheet.pdf", b"%PDF-1.4 dummy pdf content", "application/pdf")},
        )
        assert upload_res.status_code == 200, upload_res.text
        updated_comp = upload_res.json()
        assert updated_comp["datasheet_url"] is not None
        assert updated_comp["datasheet_url"].startswith("/api/v1/media/datasheets/")
        assert updated_comp["datasheet_url"].endswith(".pdf")

        # 3. Patch component: update datasheet_text and expiry_date
        patched = test_client.patch(
            f"/api/v1/components/{component['id']}",
            headers=headers,
            json={
                "datasheet_text": "Updated specifications: 3000mAh",
                "expiry_date": "2029-01-01",
            },
        )
        assert patched.status_code == 200, patched.text
        assert patched.json()["datasheet_text"] == "Updated specifications: 3000mAh"
        assert patched.json()["expiry_date"] == "2029-01-01"

        # 4. Delete datasheet file
        deleted_res = test_client.delete(
            f"/api/v1/components/{component['id']}/datasheet",
            headers=headers,
        )
        assert deleted_res.status_code == 200, deleted_res.text
        assert deleted_res.json()["datasheet_url"] is None

def test_component_sub_types() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)

        # 1. Create a parent component type (e.g. Sensors)
        parent_res = test_client.post(
            "/api/v1/component-types",
            headers=headers,
            json={"name": "Sensors Parent Group"},
        )
        assert parent_res.status_code == 200, parent_res.text
        parent_type = parent_res.json()
        assert parent_type["name"] == "Sensors Parent Group"
        assert parent_type["parent_type_id"] is None
        assert parent_type["parent_type_name"] is None

        # 2. Create a sub-type linked to the parent type (e.g. Temperature Sensor)
        child_res = test_client.post(
            "/api/v1/component-types",
            headers=headers,
            json={
                "name": "Temperature Sensor",
                "parent_type_id": parent_type["id"],
            },
        )
        assert child_res.status_code == 200, child_res.text
        child_type = child_res.json()
        assert child_type["name"] == "Temperature Sensor"
        assert child_type["parent_type_id"] == parent_type["id"]
        assert child_type["parent_type_name"] == "Sensors Parent Group"

        # 3. List component types and ensure parent_type_name is populated
        types_list = test_client.get("/api/v1/component-types", headers=headers).json()
        found_child = next((t for t in types_list if t["id"] == child_type["id"]), None)
        assert found_child is not None
        assert found_child["parent_type_name"] == "Sensors Parent Group"

        # 4. Update child type: move or clear parent
        updated_child = test_client.patch(
            f"/api/v1/component-types/{child_type['id']}",
            headers=headers,
            json={"parent_type_id": None},
        )
        assert updated_child.status_code == 200
        assert updated_child.json()["parent_type_id"] is None
        assert updated_child.json()["parent_type_name"] is None

        # 5. Prevent self-parenting
        self_parent = test_client.patch(
            f"/api/v1/component-types/{child_type['id']}",
            headers=headers,
            json={"parent_type_id": child_type["id"]},
        )
        assert self_parent.status_code == 400
        assert "cannot be its own parent" in self_parent.json()["detail"]


def test_duplicate_name_checks_for_components_types_and_locations() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]

        # 1. Component duplicate name on create and update
        comp_a = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Unique Component Alpha",
                "category_id": category["id"],
                "opening_quantity": "5",
            },
        )
        assert comp_a.status_code == 200
        comp_b = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Unique Component Beta",
                "category_id": category["id"],
                "opening_quantity": "2",
            },
        )
        assert comp_b.status_code == 200

        # Create with same name as Alpha -> 409
        dup_comp = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "  unique component alpha  ",
                "category_id": category["id"],
            },
        )
        assert dup_comp.status_code == 409
        assert "already exists" in dup_comp.json()["detail"]

        # Rename Beta to Alpha -> 409
        rename_dup = test_client.patch(
            f"/api/v1/components/{comp_b.json()['id']}",
            headers=headers,
            json={"name": "Unique Component Alpha"},
        )
        assert rename_dup.status_code == 409
        assert "already exists" in rename_dup.json()["detail"]

        # Rename Alpha to itself -> 200
        self_rename = test_client.patch(
            f"/api/v1/components/{comp_a.json()['id']}",
            headers=headers,
            json={"name": "Unique Component Alpha"},
        )
        assert self_rename.status_code == 200

        # 2. Component Type duplicate name on create and update
        type_a = test_client.post(
            "/api/v1/component-types",
            headers=headers,
            json={"name": "Unique Microcontrollers"},
        )
        assert type_a.status_code == 200
        type_b = test_client.post(
            "/api/v1/component-types",
            headers=headers,
            json={"name": "Unique Optocouplers"},
        )
        assert type_b.status_code == 200

        # Create duplicate type -> 409
        dup_type = test_client.post(
            "/api/v1/component-types",
            headers=headers,
            json={"name": "unique microcontrollers"},
        )
        assert dup_type.status_code == 409
        assert "already exists" in dup_type.json()["detail"]

        # Rename type_b to type_a -> 409
        rename_type_dup = test_client.patch(
            f"/api/v1/component-types/{type_b.json()['id']}",
            headers=headers,
            json={"name": "Unique Microcontrollers"},
        )
        assert rename_type_dup.status_code == 409
        assert "already exists" in rename_type_dup.json()["detail"]

        # 3. Location duplicate name on create and update
        loc_a = test_client.post(
            "/api/v1/locations",
            headers=headers,
            json={"name": "Shelf 99 Alpha"},
        )
        assert loc_a.status_code == 200
        loc_b = test_client.post(
            "/api/v1/locations",
            headers=headers,
            json={"name": "Shelf 99 Beta"},
        )
        assert loc_b.status_code == 200

        # Create duplicate location -> 409
        dup_loc = test_client.post(
            "/api/v1/locations",
            headers=headers,
            json={"name": "  shelf 99 alpha  "},
        )
        assert dup_loc.status_code == 409
        assert "already exists" in dup_loc.json()["detail"]

        # Rename loc_b to loc_a -> 409
        rename_loc_dup = test_client.patch(
            f"/api/v1/locations/{loc_b.json()['id']}",
            headers=headers,
            json={"name": "Shelf 99 Alpha"},
        )
        assert rename_loc_dup.status_code == 409
        assert "already exists" in rename_loc_dup.json()["detail"]


def test_suppliers_crud_and_component_supplier_association() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)

        # 1. Create suppliers
        s1 = test_client.post(
            "/api/v1/suppliers",
            headers=headers,
            json={
                "name": "DigiKey Electronics",
                "website": "https://www.digikey.com",
                "contact": "support@digikey.com",
                "notes": "Fast shipping",
            },
        )
        assert s1.status_code == 200, s1.text
        s1_data = s1.json()
        assert s1_data["name"] == "DigiKey Electronics"
        assert s1_data["website"] == "https://www.digikey.com"

        s2 = test_client.post(
            "/api/v1/suppliers",
            headers=headers,
            json={
                "name": "Mouser Electronics",
                "website": "https://www.mouser.com",
            },
        )
        assert s2.status_code == 200
        s2_id = s2.json()["id"]

        # Duplicate supplier name -> 409
        dup = test_client.post(
            "/api/v1/suppliers",
            headers=headers,
            json={"name": "  digikey electronics  "},
        )
        assert dup.status_code == 409
        assert "already exists" in dup.json()["detail"]

        # List suppliers
        suppliers = test_client.get("/api/v1/suppliers", headers=headers).json()
        names = [s["name"] for s in suppliers]
        assert "DigiKey Electronics" in names
        assert "Mouser Electronics" in names

        # Update supplier
        updated_s = test_client.patch(
            f"/api/v1/suppliers/{s2_id}",
            headers=headers,
            json={"notes": "Great for semiconductors"},
        )
        assert updated_s.status_code == 200
        assert updated_s.json()["notes"] == "Great for semiconductors"

        # Update supplier with duplicate name -> 409
        dup_update = test_client.patch(
            f"/api/v1/suppliers/{s2_id}",
            headers=headers,
            json={"name": "DigiKey Electronics"},
        )
        assert dup_update.status_code == 409

        # 2. Component with optional supplier
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]
        comp_res = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "ATmega328P-PU",
                "category_id": category["id"],
                "supplier_id": s1_data["id"],
            },
        )
        assert comp_res.status_code == 200, comp_res.text
        comp_data = comp_res.json()
        assert comp_data["supplier_id"] == s1_data["id"]
        assert comp_data["supplier_name"] == "DigiKey Electronics"

        # Component without supplier (optional)
        comp_res2 = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Generic LED 5mm Red",
                "category_id": category["id"],
            },
        )
        assert comp_res2.status_code == 200
        comp_data2 = comp_res2.json()
        assert comp_data2["supplier_id"] is None
        assert comp_data2["supplier_name"] is None

        # Update component supplier to Mouser
        update_res = test_client.patch(
            f"/api/v1/components/{comp_data2['id']}",
            headers=headers,
            json={"supplier_id": s2_id},
        )
        assert update_res.status_code == 200
        assert update_res.json()["supplier_id"] == s2_id
        assert update_res.json()["supplier_name"] == "Mouser Electronics"

        # Clear component supplier
        clear_res = test_client.patch(
            f"/api/v1/components/{comp_data2['id']}",
            headers=headers,
            json={"supplier_id": None},
        )
        assert clear_res.status_code == 200
        assert clear_res.json()["supplier_id"] is None
        assert clear_res.json()["supplier_name"] is None

        # Delete (deactivate) supplier
        del_res = test_client.delete(f"/api/v1/suppliers/{s2_id}", headers=headers)
        assert del_res.status_code == 204
        active_suppliers = test_client.get("/api/v1/suppliers", headers=headers).json()
        assert not any(s["id"] == s2_id for s in active_suppliers)


def test_project_status_conditional_stock_sorting_and_costing() -> None:
    with TestClient(app) as test_client:
        headers = auth_headers(test_client)
        category = test_client.get("/api/v1/categories", headers=headers).json()[0]

        # 1. Create two components with prices
        c1 = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Status Test IC 555",
                "category_id": category["id"],
                "opening_quantity": "50",
                "price": "1.50",
            },
        ).json()
        c2 = test_client.post(
            "/api/v1/components",
            headers=headers,
            json={
                "name": "Status Test Cap 10uF",
                "category_id": category["id"],
                "opening_quantity": "100",
                "price": "0.25",
            },
        ).json()

        # 2. Create a "To Do" project (default status)
        p_todo = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Project Beta (To Do)"},
        ).json()
        assert p_todo["status"] == "To Do"
        p_id = p_todo["id"]

        # 3. Add components to To Do project: Stock should NOT be reduced!
        put_res = test_client.put(
            f"/api/v1/projects/{p_id}/components",
            headers=headers,
            json={
                "lines": [
                    {"component_id": c1["id"], "quantity": "10"},
                    {"component_id": c2["id"], "quantity": "20"},
                ]
            },
        )
        assert put_res.status_code == 200
        # Check component price & line total_cost in response
        lines = put_res.json()
        assert len(lines) == 2
        for line in lines:
            if line["component_id"] == c1["id"]:
                assert Decimal(str(line["price"])) == Decimal("1.5000")
                assert Decimal(str(line["total_cost"])) == Decimal("15.0000")
            elif line["component_id"] == c2["id"]:
                assert Decimal(str(line["price"])) == Decimal("0.2500")
                assert Decimal(str(line["total_cost"])) == Decimal("5.0000")

        # Verify stock was NOT reduced
        c1_stock = test_client.get(f"/api/v1/components/{c1['id']}", headers=headers).json()
        c2_stock = test_client.get(f"/api/v1/components/{c2['id']}", headers=headers).json()
        assert Decimal(c1_stock["current_quantity"]) == Decimal("50.0000")
        assert Decimal(c2_stock["current_quantity"]) == Decimal("100.0000")

        # 4. Check project total cost
        p_read = test_client.get("/api/v1/projects", headers=headers).json()
        target = next(p for p in p_read if p["id"] == p_id)
        assert Decimal(str(target["total_cost"])) == Decimal("20.0000")

        # 5. Transition to "In Progress": Stock SHOULD now be reduced!
        update_res = test_client.patch(
            f"/api/v1/projects/{p_id}",
            headers=headers,
            json={"status": "In Progress"},
        )
        assert update_res.status_code == 200
        assert update_res.json()["status"] == "In Progress"

        c1_stock = test_client.get(f"/api/v1/components/{c1['id']}", headers=headers).json()
        c2_stock = test_client.get(f"/api/v1/components/{c2['id']}", headers=headers).json()
        assert Decimal(c1_stock["current_quantity"]) == Decimal("40.0000")  # 50 - 10
        assert Decimal(c2_stock["current_quantity"]) == Decimal("80.0000")  # 100 - 20

        # 6. Transition to "Completed": Stock remains reduced without duplicate deductions
        comp_res = test_client.patch(
            f"/api/v1/projects/{p_id}",
            headers=headers,
            json={"status": "Completed"},
        )
        assert comp_res.status_code == 200
        assert comp_res.json()["status"] == "Completed"

        c1_stock = test_client.get(f"/api/v1/components/{c1['id']}", headers=headers).json()
        assert Decimal(c1_stock["current_quantity"]) == Decimal("40.0000")

        # 7. Revert back to "To Do": Stock is returned!
        revert_res = test_client.patch(
            f"/api/v1/projects/{p_id}",
            headers=headers,
            json={"status": "To Do"},
        )
        assert revert_res.status_code == 200
        assert revert_res.json()["status"] == "To Do"

        c1_stock = test_client.get(f"/api/v1/components/{c1['id']}", headers=headers).json()
        c2_stock = test_client.get(f"/api/v1/components/{c2['id']}", headers=headers).json()
        assert Decimal(c1_stock["current_quantity"]) == Decimal("50.0000")
        assert Decimal(c2_stock["current_quantity"]) == Decimal("100.0000")

        # 8. Create additional projects to test sorting by status (To Do -> In Progress -> Completed) and Title
        p_comp = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Project Alpha (Completed)", "status": "Completed"},
        ).json()
        p_inprog = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Project Charlie (In Progress)", "status": "In Progress"},
        ).json()
        p_todo2 = test_client.post(
            "/api/v1/projects",
            headers=headers,
            json={"name": "Project Alpha (To Do)", "status": "To Do"},
        ).json()

        all_projects = test_client.get("/api/v1/projects", headers=headers).json()
        # Find our 4 test projects
        test_ids = {p_id, p_comp["id"], p_inprog["id"], p_todo2["id"]}
        filtered = [p for p in all_projects if p["id"] in test_ids]
        statuses_and_names = [(p["status"], p["name"]) for p in filtered]
        # Status precedence: To Do, then In Progress, then Completed; then alphabetical title
        assert statuses_and_names == [
            ("To Do", "Project Alpha (To Do)"),
            ("To Do", "Project Beta (To Do)"),
            ("In Progress", "Project Charlie (In Progress)"),
            ("Completed", "Project Alpha (Completed)"),
        ]

        # 9. Verify PDF report includes total cost
        pdf_res = test_client.get(f"/api/v1/projects/{p_id}/report.pdf", headers=headers)
        assert pdf_res.status_code == 200
        assert pdf_res.headers["content-type"] == "application/pdf"
        assert len(pdf_res.content) > 1000

        # 10. Delete project endpoint
        del_res = test_client.delete(f"/api/v1/projects/{p_id}", headers=headers)
        assert del_res.status_code == 204
        remaining = test_client.get("/api/v1/projects", headers=headers).json()
        assert not any(p["id"] == p_id for p in remaining)




