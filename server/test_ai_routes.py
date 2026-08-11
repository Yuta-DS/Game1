import json
import tempfile
import unittest
from unittest.mock import Mock, patch

from flask_jwt_extended import create_access_token

from server import server


class CreativeAiRouteTests(unittest.TestCase):
    def setUp(self):
        server.app.config["TESTING"] = True
        server.app.config["JWT_SECRET_KEY"] = "test-only-secret-key-with-32-plus-characters"
        self.cache_directory = tempfile.TemporaryDirectory()
        self.original_cache_directory = server.AI_CACHE_DIR
        server.AI_CACHE_DIR = self.cache_directory.name
        with server.AI_CIRCUIT_LOCK:
            server.AI_CIRCUITS.clear()
        self.client = server.app.test_client()
        with server.app.app_context():
            token = create_access_token(identity="1")
        self.headers = {"Authorization": f"Bearer {token}"}

    def tearDown(self):
        server.AI_CACHE_DIR = self.original_cache_directory
        self.cache_directory.cleanup()

    @staticmethod
    def _upstream_response(payload):
        response = Mock()
        response.status_code = 200
        response.json.return_value = {
            "choices": [{
                "message": {"content": json.dumps(payload)}
            }]
        }
        return response

    @staticmethod
    def _semantic_world(title="Vision World", subject_id="tree", subject_type="tree"):
        return {
            "schema_version": 2,
            "world_title": title,
            "objects": [{
                "id": subject_id,
                "type": subject_type,
                "description": f"the painted {subject_type}",
                "normalized_position": {"x": 0.5, "y": 0.5},
                "bounding_box": {"x": 0.3, "y": 0.2, "width": 0.4, "height": 0.6},
            }],
            "characters": [],
            "animations": [],
            "interactions": [],
        }

    def test_status_reports_configuration_without_secrets(self):
        response = self.client.get("/ai/status")
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(body["creative_guide"]["configured"])
        self.assertTrue(body["world_builder"]["configured"])
        self.assertTrue(body["recovery"]["backup_key_configured"])
        self.assertTrue(body["recovery"]["offline_fallback"])
        self.assertNotIn("api_key", json.dumps(body).lower())
        self.assertNotIn("sk-", json.dumps(body).lower())

    @patch("server.server.requests.post")
    def test_creative_guide_uses_guide_route(self, post):
        post.return_value = self._upstream_response({
            "title": "Moon Garden",
            "style_ideas": ["watercolor", "paper collage", "soft pastel"]
        })

        response = self.client.post(
            "/ai/creative-guide",
            headers=self.headers,
            json={"title": "My Moon", "prompt": "Give me gentle ideas"}
        )
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["model"], server.OMNIROUTE_CREATIVE_GUIDE_MODEL)
        self.assertEqual(body["guide"]["title"], "Moon Garden")
        request_payload = post.call_args.kwargs["json"]
        self.assertEqual(request_payload["reasoning_effort"], "none")
        self.assertEqual(request_payload["model"], server.OMNIROUTE_CREATIVE_GUIDE_MODEL)

    @patch("server.server.requests.post")
    def test_loopback_guest_can_build_a_world_without_a_login_token(self, post):
        post.return_value = self._upstream_response(self._semantic_world("Guest Garden"))

        response = self.client.post(
            "/ai/world-builder",
            json={"title": "Guest Garden", "prompt": "Make the tree sway"}
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["world_manifest"]["objects"][0]["type"], "tree")

    def test_remote_guest_cannot_use_paid_ai_routes(self):
        response = self.client.post(
            "/ai/world-builder",
            json={"prompt": "Build a world"},
            environ_base={"REMOTE_ADDR": "203.0.113.9"}
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json()["error"], "Authentication required")

    def test_legacy_named_subjects_upgrade_to_spatial_semantic_objects(self):
        upgraded = server._upgrade_legacy_semantic_manifest({
            "world_title": "Painted Lake",
            "environment": "A lake below mountain foothills",
            "objects": [
                {"id": "girl", "type": "character", "position_hint": "foreground"},
                {"id": "main_boat", "type": "structure", "position_hint": "center-left"},
                {"id": "pink_pagoda", "type": "structure", "position_hint": "background left"},
                {"id": "willow_tree", "type": "structure", "position_hint": "right"},
            ],
            "characters": [{"id": "girl", "type": "avatar"}],
        })

        self.assertTrue(server._semantic_world_manifest_is_complete(upgraded))
        self.assertEqual(upgraded["schema_version"], 2)
        self.assertEqual(
            [item["type"] for item in upgraded["objects"]],
            ["person", "boat", "pagoda", "tree", "water", "mountain"]
        )
        self.assertTrue(all("bounding_box" in item for item in upgraded["objects"]))

    @patch("server.server.requests.post")
    def test_incomplete_vision_manifest_is_not_presented_as_a_world(self, post):
        incomplete = self._upstream_response({
            "world_title": "Block World",
            "objects": [{"id": "shape", "type": "structure"}]
        })
        post.side_effect = [incomplete, incomplete]

        response = self.client.post(
            "/ai/world-builder",
            json={"title": "Block World", "prompt": "Build this world"}
        )
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["ai_source"], "offline")
        self.assertFalse(body["semantic_ready"])

    @patch("server.server.requests.post")
    def test_world_builder_can_update_an_existing_world(self, post):
        post.return_value = self._upstream_response(
            self._semantic_world("Bird Castle", "castle", "castle")
        )

        response = self.client.post(
            "/ai/world-builder",
            headers=self.headers,
            json={
                "prompt": "Add a friendly bird",
                "creative_brief": {"scene_description": "A pink castle"},
                "existing_manifest": {"world_title": "Bird Castle"}
            }
        )
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["task"], "update_world")
        self.assertEqual(body["model"], server.OMNIROUTE_WORLD_BUILDER_MODEL)
        request_payload = post.call_args.kwargs["json"]
        self.assertEqual(request_payload["model"], server.OMNIROUTE_WORLD_BUILDER_MODEL)
        world_instruction = request_payload["messages"][0]["content"]
        self.assertIn("schema_version 2", world_instruction)
        self.assertIn("every clearly visible subject", world_instruction)
        self.assertIn("bounding_box", world_instruction)
        authorization = post.call_args.kwargs["headers"]["Authorization"]
        self.assertEqual(
            authorization,
            f"Bearer {server.OMNIROUTE_WORLD_BUILDER_API_KEY}"
        )

    @patch("server.server.requests.post")
    def test_primary_key_failure_uses_emergency_backup(self, post):
        rejected = Mock()
        rejected.status_code = 401
        post.side_effect = [
            rejected,
            self._upstream_response({"title": "Backup Guide"})
        ]

        response = self.client.post(
            "/ai/creative-guide",
            headers=self.headers,
            json={"title": "Backup Test", "prompt": "Give me an idea"}
        )
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["status"], "ok")
        self.assertEqual(body["ai_source"], "backup")
        self.assertFalse(body["degraded"])
        backup_authorization = post.call_args_list[1].kwargs["headers"]["Authorization"]
        self.assertEqual(
            backup_authorization,
            f"Bearer {server.OMNIROUTE_BACKUP_API_KEY}"
        )

    @patch("server.server.requests.post")
    def test_total_outage_returns_offline_guide(self, post):
        unavailable = Mock()
        unavailable.status_code = 503
        post.side_effect = [unavailable, unavailable]

        response = self.client.post(
            "/ai/creative-guide",
            headers=self.headers,
            json={"title": "Offline Moon", "prompt": "Help me continue"}
        )
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["status"], "offline_fallback")
        self.assertEqual(body["ai_source"], "offline")
        self.assertTrue(body["degraded"])
        self.assertTrue(body["guide"]["offline"])

    @patch("server.server.requests.post")
    def test_cached_result_is_reused_during_an_outage(self, post):
        request_body = {"title": "Cached Moon", "prompt": "Show gentle styles"}
        post.return_value = self._upstream_response({"title": "Cached Result"})

        first = self.client.post(
            "/ai/creative-guide",
            headers=self.headers,
            json=request_body
        )
        self.assertEqual(first.status_code, 200)

        unavailable = Mock()
        unavailable.status_code = 503
        post.reset_mock()
        post.side_effect = [unavailable, unavailable]

        second = self.client.post(
            "/ai/creative-guide",
            headers=self.headers,
            json=request_body
        )
        body = second.get_json()

        self.assertEqual(second.status_code, 200)
        self.assertEqual(body["status"], "cached_fallback")
        self.assertEqual(body["ai_source"], "cache")
        self.assertEqual(body["guide"]["title"], "Cached Result")

    @patch("server.server.requests.post")
    def test_world_outage_preserves_existing_manifest(self, post):
        unavailable = Mock()
        unavailable.status_code = 503
        post.side_effect = [unavailable, unavailable]
        existing = {
            "world_title": "My First World",
            "objects": [{"id": "castle"}]
        }

        response = self.client.post(
            "/ai/world-builder",
            headers=self.headers,
            json={
                "prompt": "Add a bird",
                "existing_manifest": existing
            }
        )
        body = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["status"], "offline_fallback")
        self.assertEqual(body["world_manifest"]["objects"], existing["objects"])
        self.assertEqual(body["world_manifest"]["recovery"]["mode"], "offline")

    @patch("server.server.requests.get")
    def test_health_probe_restores_an_open_key_circuit(self, get):
        server._record_circuit_failure(
            "creative_guide:primary",
            "temporary failure"
        )
        healthy = Mock()
        healthy.status_code = 200
        get.return_value = healthy

        server._probe_open_circuits_once()

        state = server._circuit_state("creative_guide:primary")
        self.assertEqual(state["failures"], 0)
        self.assertEqual(state["opened_until"], 0.0)

    def test_rejects_invalid_artwork_data(self):
        response = self.client.post(
            "/ai/creative-guide",
            headers=self.headers,
            json={"artwork_base64": "not-base64!"}
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"], "Invalid base64 artwork")


if __name__ == "__main__":
    unittest.main()
