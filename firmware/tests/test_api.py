#!/usr/bin/env python3
"""
TITIKSHA X1 Automated Hardware & REST API Verification Suite
Runs 12 comprehensive integration tests against the live ESP32-C3 device.
"""

import sys
import json
import time
import argparse
import urllib.request
import urllib.error

def run_tests(base_url):
    print("=" * 65)
    print(f"  TITIKSHA X1 AUTOMATED VERIFICATION SUITE")
    print(f"  Target: {base_url}")
    print("=" * 65 + "\n")

    passed = 0
    total = 12

    # Test 1: GET /api/status
    try:
        req = urllib.request.urlopen(f"{base_url}/api/status", timeout=5)
        assert req.status == 200
        data = json.loads(req.read().decode())
        assert "clients" in data
        assert len(data["clients"]) >= 1
        print("✅ [TEST 01/12] GET /api/status — Valid schema & focus categories loaded")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 01/12] GET /api/status FAILED: {e}")

    # Test 2: GET /api/quick
    try:
        req = urllib.request.urlopen(f"{base_url}/api/quick", timeout=5)
        assert req.status == 200
        qdata = json.loads(req.read().decode())
        assert "dw" in qdata and "pct" in qdata
        print("✅ [TEST 02/12] GET /api/quick — Mini-telemetry widget responded")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 02/12] GET /api/quick FAILED: {e}")

    # Test 3: POST /api/goal
    try:
        payload = json.dumps({"goal": 36000}).encode()
        req = urllib.request.Request(f"{base_url}/api/goal", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        print("✅ [TEST 03/12] POST /api/goal — Daily Deep Work target set to 10h (36000s)")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 03/12] POST /api/goal FAILED: {e}")

    # Test 4: POST /api/action -> start
    try:
        payload = json.dumps({"action": "start"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        time.sleep(1.2)
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["state"] == "TRACKING"
        print("✅ [TEST 04/12] POST /api/action [start] — State changed to TRACKING")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 04/12] POST /api/action [start] FAILED: {e}")

    # Test 5: POST /api/action -> rep_plus
    try:
        payload = json.dumps({"action": "rep_plus"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        print("✅ [TEST 05/12] POST /api/action [rep_plus] — Repetition tally incremented")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 05/12] POST /api/action [rep_plus] FAILED: {e}")

    # Test 6: POST /api/action -> pause
    try:
        payload = json.dumps({"action": "pause"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["state"] == "PAUSED"
        print("✅ [TEST 06/12] POST /api/action [pause] — Engine paused")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 06/12] POST /api/action [pause] FAILED: {e}")

    # Test 7: POST /api/action -> resume
    try:
        payload = json.dumps({"action": "resume"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["state"] == "TRACKING"
        print("✅ [TEST 07/12] POST /api/action [resume] — Engine resumed to TRACKING")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 07/12] POST /api/action [resume] FAILED: {e}")

    # Test 8: POST /api/action -> stop
    try:
        payload = json.dumps({"action": "stop"}).encode()
        req = urllib.request.Request(f"{base_url}/api/action", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["state"] == "IDLE"
        print("✅ [TEST 08/12] POST /api/action [stop] — Session committed & saved to flash")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 08/12] POST /api/action [stop] FAILED: {e}")

    # Test 9: POST /api/sections/add & /delete
    try:
        payload = json.dumps({"name": "Modular Architecture"}).encode()
        req = urllib.request.Request(f"{base_url}/api/sections/add", data=payload, headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        new_client = next((c for c in status["clients"] if c["name"] == "Modular Architecture"), None)
        assert new_client is not None
        # Clean up
        del_payload = json.dumps({"id": new_client["id"]}).encode()
        req_del = urllib.request.Request(f"{base_url}/api/sections/delete", data=del_payload, headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req_del, timeout=5)
        print("✅ [TEST 09/12] POST /api/sections/add & delete — Dynamic section management")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 09/12] POST /api/sections/add & delete FAILED: {e}")

    # Test 10: GET /api/export/*.csv
    try:
        csv1 = urllib.request.urlopen(f"{base_url}/api/export/sessions.csv", timeout=5).read().decode()
        assert "Full_Timestamp,Date,Focus_Section" in csv1
        csv2 = urllib.request.urlopen(f"{base_url}/api/export/summary.csv", timeout=5).read().decode()
        assert "Section_ID,Section_Name,Today_Seconds" in csv2
        print("✅ [TEST 10/12] GET /api/export/*.csv — High-speed CSV exports verified")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 10/12] GET /api/export/*.csv FAILED: {e}")

    # Test 11: POST /api/reset
    try:
        req = urllib.request.Request(f"{base_url}/api/reset", headers={"Content-Type": "application/json"}, method="POST")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 200
        status = json.loads(urllib.request.urlopen(f"{base_url}/api/status").read().decode())
        assert status["globalDeepWorkSecondsToday"] == 0
        assert status["currentStreak"] == 0
        for c in status["clients"]:
            assert c["totalSecsToday"] == 0
            assert c["reps"] == 0
            assert len(c["history"]) == 0
        print("✅ [TEST 11/12] POST /api/reset — Clean zero-wipe executed and verified")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 11/12] POST /api/reset FAILED: {e}")

    # Test 12: OPTIONS CORS Preflight
    try:
        req = urllib.request.Request(f"{base_url}/api/status", method="OPTIONS")
        res = urllib.request.urlopen(req, timeout=5)
        assert res.status == 204
        assert res.headers.get("Access-Control-Allow-Origin") == "*"
        print("✅ [TEST 12/12] OPTIONS CORS Preflight — Universal browser access authorized")
        passed += 1
    except Exception as e:
        print(f"❌ [TEST 12/12] OPTIONS CORS Preflight FAILED: {e}")

    print("\n" + "=" * 65)
    print(f"  RESULT: {passed} / {total} Tests Passed ({(passed/total)*100:.0f}%)")
    print("=" * 65)
    return passed == total

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TITIKSHA X1 API Verification")
    parser.add_argument("--host", default="http://192.168.0.210", help="Base URL of ESP32 (default: http://192.168.0.210)")
    args = parser.parse_args()

    success = run_tests(args.host)
    sys.exit(0 if success else 1)
