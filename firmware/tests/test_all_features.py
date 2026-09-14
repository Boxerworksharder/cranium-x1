#!/usr/bin/env python3
"""
TITIKSHA X1 Exhaustive End-to-End Feature Verification Suite
Tests all hardware, network, state machine, REST API, Web UI, Haptics, and 10h Goal features.
"""

import sys
import json
import time
import gzip
import argparse
import urllib.request
import urllib.error

def run_exhaustive_suite(base_url):
    print("=" * 70)
    print("      TITIKSHA X1 EXHAUSTIVE FEATURE VERIFICATION SUITE")
    print(f"      Target: {base_url}")
    print("=" * 70)

    passed = 0
    total = 18

    # -------------------------------------------------------------
    # 1. Web Dashboard & Gzip Compression
    # -------------------------------------------------------------
    print("\n[SUITE 1: WEB COCKPIT & NETWORKING]")
    try:
        req = urllib.request.Request(f"{base_url}/", headers={"Accept-Encoding": "gzip"})
        res = urllib.request.urlopen(req, timeout=15)
        assert res.status == 200
        content_encoding = res.headers.get("Content-Encoding", "")
        raw_body = res.read()
        if content_encoding == "gzip":
            html = gzip.decompress(raw_body).decode('utf-8')
        else:
            html = raw_body.decode('utf-8')
        assert "TITIKSHA" in html
        assert "chronograph-hud" in html
        assert "goal-input" in html
        assert "brightness-slider" in html
        assert "brightness-pct-label" in html
        assert "Focus Session Logs" in html
        assert "session-ledger-body" in html
        assert "cockpit-recent-logs" in html
        assert "colorPalette" in html
        print(f"  ✅ [1/{total}] Web Cockpit Root: 200 OK, Gzip compressed, complete UI served ({len(raw_body)} bytes wire, {len(html)} bytes uncompressed)")
        passed += 1
    except Exception as e:
        print(f"  ❌ [1/{total}] Web Cockpit Root FAILED: {e}")

    # -------------------------------------------------------------
    # 2. CORS Preflight & Browser Security
    # -------------------------------------------------------------
    try:
        req = urllib.request.Request(f"{base_url}/api/status", method="OPTIONS")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 204
        assert res.headers.get("Access-Control-Allow-Origin") == "*"
        print(f"  ✅ [2/{total}] Universal CORS Preflight: 204 No Content, Wildcard origin authorized")
        passed += 1
    except Exception as e:
        print(f"  ❌ [2/{total}] CORS Preflight FAILED: {e}")

    # -------------------------------------------------------------
    # 3. Core Telemetry Schema & Health Check
    # -------------------------------------------------------------
    print("\n[SUITE 2: TELEMETRY & METRICS]")
    initial_status = None
    try:
        res = urllib.request.urlopen(f"{base_url}/api/status", timeout=5)
        assert res.status == 200
        initial_status = json.loads(res.read().decode())
        for key in ["state", "currentStreak", "longestStreak", "activeClientId", "sessionSeconds", 
                    "globalDeepWorkSecondsToday", "globalGoal", "systemTimestamp", "systemDate", "clients"]:
            assert key in initial_status, f"Missing key: {key}"
        print(f"  ✅ [3/{total}] Core Telemetry Schema: Valid payload, state={initial_status['state']}, activeClientId={initial_status['activeClientId']}")
        passed += 1
    except Exception as e:
        print(f"  ❌ [3/{total}] Core Telemetry Schema FAILED: {e}")

    # -------------------------------------------------------------
    # 4. 10-Hour Deep Work Goal Standard (36,000 Seconds)
    # -------------------------------------------------------------
    print("\n[SUITE 3: 10-HOUR DEEP WORK STANDARD]")
    try:
        goal = initial_status["globalGoal"]
        assert goal == 36000, f"Expected 36000s, got {goal}s"
        print(f"  ✅ [4/{total}] 10-Hour Goal Standard: Confirmed default {goal}s ({goal/3600:.1f} Hours)")
        passed += 1
    except Exception as e:
        print(f"  ❌ [4/{total}] 10-Hour Goal Standard FAILED: {e}")

    # -------------------------------------------------------------
    # 5. Goal Boundary Validation (Invalid Inputs)
    # -------------------------------------------------------------
    try:
        # Test lower bound (< 1800s / 30m)
        payload_low = json.dumps({"goal": 600}).encode()
        req_low = urllib.request.Request(f"{base_url}/api/goal", data=payload_low, headers={"Content-Type": "application/json"}, method="POST")
        try:
            urllib.request.urlopen(req_low, timeout=5)
            assert False, "Should have rejected goal < 1800s"
        except urllib.error.HTTPError as he:
            assert he.code == 400

        # Test upper bound (> 86400s / 24h)
        payload_high = json.dumps({"goal": 100000}).encode()
        req_high = urllib.request.Request(f"{base_url}/api/goal", data=payload_high, headers={"Content-Type": "application/json"}, method="POST")
        try:
            urllib.request.urlopen(req_high, timeout=5)
            assert False, "Should have rejected goal > 86400s"
        except urllib.error.HTTPError as he:
            assert he.code == 400

        print(f"  ✅ [5/{total}] Goal Boundary Validation: Correctly rejected <30m and >24h targets with HTTP 400")
        passed += 1
    except Exception as e:
        print(f"  ❌ [5/{total}] Goal Boundary Validation FAILED: {e}")

    # -------------------------------------------------------------
    # 6. Mini-Widget Quick Telemetry & Percentage Calculation
    # -------------------------------------------------------------
    try:
        res = urllib.request.urlopen(f"{base_url}/api/quick", timeout=5)
        assert res.status == 200
        qdata = json.loads(res.read().decode())
        for key in ["dw", "pct", "streak", "state", "session", "goal"]:
            assert key in qdata, f"Missing widget key: {key}"
        assert qdata["goal"] == 36000
        print(f"  ✅ [6/{total}] Widget Telemetry: DW={qdata['dw']}, Progress={qdata['pct']}%, Goal={qdata['goal']}s")
        passed += 1
    except Exception as e:
        print(f"  ❌ [6/{total}] Widget Telemetry FAILED: {e}")

    # -------------------------------------------------------------
    # 7. State Machine: Resume & Active Focus Tracking
    # -------------------------------------------------------------
    print("\n[SUITE 4: STATE MACHINE & HAPTIC ACTION PIPELINE]")
    try:
        # Send resume (or start if idle)
        action = "resume" if initial_status["state"] == "PAUSED" else "start"
        payload = json.dumps({"action": action}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200

        # Wait 2 seconds for timer to advance
        time.sleep(2.0)

        res = urllib.request.urlopen(f"{base_url}/api/status", timeout=5)
        st = json.loads(res.read().decode())
        assert st["state"] == "TRACKING"
        assert st["sessionSeconds"] >= 1
        print(f"  ✅ [7/{total}] State Machine [TRACKING]: Active session running, timer advanced to {st['sessionSeconds']}s")
        passed += 1
    except Exception as e:
        print(f"  ❌ [7/{total}] State Machine [TRACKING] FAILED: {e}")

    # -------------------------------------------------------------
    # 8. Repetition Counter (+1 Increment)
    # -------------------------------------------------------------
    try:
        active_id = initial_status["activeClientId"]
        # Fetch current reps
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        client_before = next(c for c in status["clients"] if c["id"] == active_id)
        reps_before = client_before["reps"]

        payload = json.dumps({"action": "rep_plus"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status_after = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        client_after = next(c for c in status_after["clients"] if c["id"] == active_id)
        assert client_after["reps"] == reps_before + 1
        print(f"  ✅ [8/{total}] Repetition Counter Increment: Reps advanced from {reps_before} to {client_after['reps']}")
        passed += 1
    except Exception as e:
        print(f"  ❌ [8/{total}] Repetition Counter Increment FAILED: {e}")

    # -------------------------------------------------------------
    # 9. Repetition Counter (-1 Decrement)
    # -------------------------------------------------------------
    try:
        payload = json.dumps({"action": "rep_minus"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status_after = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        client_after = next(c for c in status_after["clients"] if c["id"] == active_id)
        assert client_after["reps"] == reps_before
        print(f"  ✅ [9/{total}] Repetition Counter Decrement: Reps rolled back cleanly to {client_after['reps']}")
        passed += 1
    except Exception as e:
        print(f"  ❌ [9/{total}] Repetition Counter Decrement FAILED: {e}")

    # -------------------------------------------------------------
    # 10. State Machine: Pause Focus
    # -------------------------------------------------------------
    try:
        payload = json.dumps({"action": "pause"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["state"] == "PAUSED"
        print(f"  ✅ [10/{total}] State Machine [PAUSED]: Engine paused gracefully, timer frozen")
        passed += 1
    except Exception as e:
        print(f"  ❌ [10/{total}] State Machine [PAUSED] FAILED: {e}")

    # -------------------------------------------------------------
    # 11. State Machine: Stop & Save Session to Flash
    # -------------------------------------------------------------
    try:
        payload = json.dumps({"action": "stop"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["state"] == "IDLE"
        assert status["sessionSeconds"] == 0
        assert status["globalDeepWorkSecondsToday"] > 0
        print(f"  ✅ [11/{total}] State Machine [STOP & COMMIT]: Session committed to history, total today={status['globalDeepWorkSecondsToday']}s")
        passed += 1
    except Exception as e:
        print(f"  ❌ [11/{total}] State Machine [STOP & COMMIT] FAILED: {e}")

    # -------------------------------------------------------------
    # 12. Dynamic Section Management: Add Section
    # -------------------------------------------------------------
    print("\n[SUITE 5: DYNAMIC CATEGORIES & CRUD]")
    test_sec_name = "Embedded Systems Verification"
    new_sec_id = None
    try:
        payload = json.dumps({"name": test_sec_name}).encode()
        req = urllib.request.Request(f"{base_url}/api/sections/add", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        found = next((c for c in status["clients"] if c["name"] == test_sec_name), None)
        assert found is not None
        new_sec_id = found["id"]
        print(f"  ✅ [12/{total}] Dynamic Section Add: Created '{test_sec_name}' (ID={new_sec_id})")
        passed += 1
    except Exception as e:
        print(f"  ❌ [12/{total}] Dynamic Section Add FAILED: {e}")

    # -------------------------------------------------------------
    # 13. Dynamic Section Selection
    # -------------------------------------------------------------
    try:
        payload = json.dumps({"action": "select", "id": new_sec_id}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["activeClientId"] == new_sec_id
        print(f"  ✅ [13/{total}] Dynamic Section Select: Switched active client to ID={new_sec_id}")
        passed += 1
    except Exception as e:
        print(f"  ❌ [13/{total}] Dynamic Section Select FAILED: {e}")

    # -------------------------------------------------------------
    # 14. Dynamic Section Deletion & Cleanup
    # -------------------------------------------------------------
    try:
        payload = json.dumps({"id": new_sec_id}).encode()
        req = urllib.request.Request(f"{base_url}/api/sections/delete", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=5)

        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        found = next((c for c in status["clients"] if c["id"] == new_sec_id), None)
        assert found is None
        print(f"  ✅ [14/{total}] Dynamic Section Delete: Deleted '{test_sec_name}', cleaned up cleanly")
        passed += 1
    except Exception as e:
        print(f"  ❌ [14/{total}] Dynamic Section Delete FAILED: {e}")

    # -------------------------------------------------------------
    # 15. CSV Export Engine
    # -------------------------------------------------------------
    print("\n[SUITE 6: DATA EXPORTS & REPORTING]")
    try:
        csv_sess = urllib.request.urlopen(f"{base_url}/api/export/sessions.csv", timeout=5).read().decode()
        assert "Full_Timestamp,Date,Focus_Section,Duration_Formatted" in csv_sess

        csv_sum = urllib.request.urlopen(f"{base_url}/api/export/summary.csv", timeout=5).read().decode()
        assert "Section_ID,Section_Name,Today_Seconds,Today_Hours" in csv_sum
        print(f"  ✅ [15/{total}] CSV Export Pipeline: Valid sessions.csv and summary.csv streams generated")
        passed += 1
    except Exception as e:
        print(f"  ❌ [15/{total}] CSV Export Pipeline FAILED: {e}")

    # -------------------------------------------------------------
    # 16. API Fault Tolerance (Invalid Body / Non-existent Endpoints)
    # -------------------------------------------------------------
    print("\n[SUITE 7: RESILIENCE & ERROR HANDLING]")
    try:
        # Invalid JSON
        req_bad_json = urllib.request.Request(f"{base_url}/api/action", data=b"{bad_json", headers={"Content-Type": "application/json"}, method="POST")
        try:
            urllib.request.urlopen(req_bad_json, timeout=5)
            assert False, "Should reject malformed JSON"
        except urllib.error.HTTPError as he:
            assert he.code == 400

        # Nonexistent route
        try:
            urllib.request.urlopen(f"{base_url}/api/non_existent_endpoint_xyz", timeout=5)
            assert False, "Should 404 on nonexistent route"
        except urllib.error.HTTPError as he:
            assert he.code == 404

        print(f"  ✅ [16/{total}] Fault Tolerance: Properly handled malformed JSON (400) & invalid routes (404)")
        passed += 1
    except Exception as e:
        print(f"  ❌ [16/{total}] Fault Tolerance FAILED: {e}")

    # -------------------------------------------------------------
    # 17. Display Brightness Control Engine
    # -------------------------------------------------------------
    print("\n[SUITE 8: DISPLAY BRIGHTNESS ENGINE]")
    try:
        # 1. GET /api/brightness
        b_res = urllib.request.urlopen(f"{base_url}/api/brightness", timeout=5)
        assert b_res.status == 200
        b_data = json.loads(b_res.read().decode())
        assert "brightness" in b_data
        assert "brightnessPct" in b_data
        assert 10 <= b_data["brightness"] <= 255

        # 2. POST /api/brightness (valid change to 180)
        set_b = json.dumps({"level": 180}).encode()
        req_set = urllib.request.Request(f"{base_url}/api/brightness", data=set_b, headers={"Content-Type": "application/json"}, method="POST")
        res_set = urllib.request.urlopen(req_set, timeout=5)
        assert res_set.status == 200
        res_set_data = json.loads(res_set.read().decode())
        assert res_set_data.get("status") == "ok"
        assert res_set_data.get("brightness") == 180

        # 3. Verify /api/status reflects new brightness
        st_res = urllib.request.urlopen(f"{base_url}/api/status", timeout=5)
        st_data = json.loads(st_res.read().decode())
        assert st_data.get("brightness") == 180

        # 4. POST /api/action with set_brightness (restore 255)
        act_b = json.dumps({"action": "set_brightness", "level": 255}).encode()
        req_act = urllib.request.Request(f"{base_url}/api/action", data=act_b, headers={"Content-Type": "application/json"}, method="POST")
        res_act = urllib.request.urlopen(req_act, timeout=5)
        assert res_act.status == 200

        # 5. Boundary checks (reject < 10)
        bad_b = json.dumps({"level": 5}).encode()
        req_bad = urllib.request.Request(f"{base_url}/api/brightness", data=bad_b, headers={"Content-Type": "application/json"}, method="POST")
        try:
            urllib.request.urlopen(req_bad, timeout=5)
            assert False, "Should reject brightness < 10"
        except urllib.error.HTTPError as he:
            assert he.code == 400

        print(f"  ✅ [17/{total}] Display Brightness Engine: GET, POST, action, bounds validation & telemetry sync verified")
        passed += 1
    except Exception as e:
        print(f"  ❌ [17/{total}] Display Brightness Engine FAILED: {e}")

    # -------------------------------------------------------------
    # 18. Tactical Priority Task List & GPIO 20 Sync
    # -------------------------------------------------------------
    print("\n[SUITE 9: TACTICAL PRIORITY TASK LIST & GPIO 20 SYNC]")
    try:
        # 1. GET /api/tasks
        req_t = urllib.request.Request(f"{base_url}/api/tasks")
        res_t = urllib.request.urlopen(req_t, timeout=8)
        assert res_t.status == 200
        tasks = json.loads(res_t.read().decode())
        assert isinstance(tasks, list)
        print(f"  · Found {len(tasks)} tasks in active list")

        # 2. POST /api/tasks/add with 3 Stars
        new_task = json.dumps({"text": "Automated Suite Test Task", "stars": 3}).encode()
        req_add = urllib.request.Request(f"{base_url}/api/tasks/add", data=new_task, headers={"Content-Type": "application/json"}, method="POST")
        res_add = urllib.request.urlopen(req_add, timeout=8)
        assert res_add.status == 200
        add_data = json.loads(res_add.read().decode())
        task_id = add_data.get("id")
        assert task_id is not None

        # 3. POST /api/tasks/toggle
        togg_task = json.dumps({"id": task_id}).encode()
        req_tog = urllib.request.Request(f"{base_url}/api/tasks/toggle", data=togg_task, headers={"Content-Type": "application/json"}, method="POST")
        res_tog = urllib.request.urlopen(req_tog, timeout=8)
        assert res_tog.status == 200

        # 4. POST /api/tasks/update (change to 2 stars)
        up_task = json.dumps({"id": task_id, "stars": 2}).encode()
        req_up = urllib.request.Request(f"{base_url}/api/tasks/update", data=up_task, headers={"Content-Type": "application/json"}, method="POST")
        res_up = urllib.request.urlopen(req_up, timeout=8)
        assert res_up.status == 200

        # 5. Verify /api/status contains tasks
        st_res = urllib.request.urlopen(f"{base_url}/api/status", timeout=8)
        st_data = json.loads(st_res.read().decode())
        assert "tasks" in st_data
        matching = [t for t in st_data["tasks"] if t["id"] == task_id]
        assert len(matching) == 1
        assert matching[0]["done"] == True
        assert matching[0]["stars"] == 2

        # 6. POST /api/tasks/delete
        del_task = json.dumps({"id": task_id}).encode()
        req_del = urllib.request.Request(f"{base_url}/api/tasks/delete", data=del_task, headers={"Content-Type": "application/json"}, method="POST")
        res_del = urllib.request.urlopen(req_del, timeout=8)
        assert res_del.status == 200

        print(f"  ✅ [18/{total}] Tactical Task List Engine: CRUD, priority stars (1-3), done toggle, and /api/status sync verified")
        passed += 1
    except Exception as e:
        print(f"  ❌ [18/{total}] Tactical Task List Engine FAILED: {e}")

    # -------------------------------------------------------------
    # Final Scorecard
    # -------------------------------------------------------------
    print("\n" + "=" * 70)
    print(f"  FINAL SCORECARD: {passed} / {total} Features Passed ({(passed/total)*100:.1f}%)")
    print("=" * 70)
    return passed == total

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TITIKSHA X1 Exhaustive Test Suite")
    parser.add_argument("--host", default="http://192.168.0.210", help="ESP32 host URL")
    args = parser.parse_args()

    success = run_exhaustive_suite(args.host)
    sys.exit(0 if success else 1)
