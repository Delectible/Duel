"""Live check after a deploy: two throwaway anonymous players (as the app
signs in) make a party, play Four in a Row through the referee to a win,
and read the game from Firestore through the security rules. The players
are deleted at the end.

python3 tool/online/smoke.py <referee-url> <project-id> <web-api-key>
"""
import json
import sys
import urllib.error
import urllib.request

REF, PROJECT, KEY = sys.argv[1].rstrip("/"), sys.argv[2], sys.argv[3]
IDT = "https://identitytoolkit.googleapis.com/v1/accounts"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def call(method, url, body=None, token=None, ok=(200,)):
    req = urllib.request.Request(url, method=method, data=None if body is None else json.dumps(body).encode())
    req.add_header("content-type", "application/json")
    if token:
        req.add_header("authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            status, text = r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read().decode()
    if status not in ok:
        sys.exit(f"FAIL {method} {url.split('?')[0]}: {status} {text[:300]}")
    return status, (json.loads(text) if text.strip().startswith(("{", "[")) else text)


def player():
    _, r = call("POST", f"{IDT}:signUp?key={KEY}", {"returnSecureToken": True})
    return r["idToken"], r["localId"]


(a, a_uid), (b, b_uid), (c, _) = player(), player(), player()
try:
    call("GET", f"{REF}/health")
    call("POST", f"{REF}/v1/parties", {}, ok=(401,))  # no token: turned away
    _, party = call("POST", f"{REF}/v1/parties", {"name": "Smoke A"}, a)
    _, party = call("POST", f"{REF}/v1/parties/join", {"code": party["code"], "name": "Smoke B"}, b)
    assert sorted(party["members"]) == sorted([a_uid, b_uid]), party
    _, m = call("POST", f"{REF}/v1/parties/{party['id']}/start", {"game": "connect4"}, a)
    tokens = {a_uid: a, b_uid: b}
    for col in [0, 1, 0, 1, 0, 1, 0]:  # whoever starts wins down column 0
        who = tokens[m["seats"][m["turn"]]]
        _, m = call("POST", f"{REF}/v1/matches/{m['id']}/move", {"version": m["version"], "move": {"column": col}}, who)
    assert m["status"] == "over" and m["result"]["reason"] == "won", m
    # A stale move is refused.
    call("POST", f"{REF}/v1/matches/{m['id']}/move", {"version": 1, "move": {"column": 3}}, a, ok=(409,))
    # Rules: players read their game; an outsider can't; nobody writes it.
    _, doc = call("GET", f"{FS}/matches/{m['id']}", token=b)
    assert doc["fields"]["status"]["stringValue"] == "over"
    call("GET", f"{FS}/matches/{m['id']}", token=c, ok=(403,))
    call("PATCH", f"{FS}/matches/{m['id']}", {"fields": {}}, a, ok=(403,))
    call("POST", f"{REF}/v1/parties/{party['id']}/leave", {}, a)
    call("POST", f"{REF}/v1/parties/{party['id']}/leave", {}, b)
    print(f"OK: party, {len(m['state']['moves'])} moves to a win, stale move refused, rules hold")
finally:
    for t in (a, b, c):
        call("POST", f"{IDT}:delete?key={KEY}", {"idToken": t})
