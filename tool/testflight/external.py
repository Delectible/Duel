"""Sends a TestFlight build to the external testers: adds it to the
"Friends" group (or BETA_GROUP), sets its "What to test" from
AppInfo.latest, and submits it for Apple's beta review. Run by
promote-closed.yml next to Play's closed testing.

    python3 tool/testflight/external.py [build]   (empty = newest build)

Env: APPSTORE_KEY (the .p8 text), APPSTORE_KEY_ID, APPSTORE_ISSUER_ID.
Needs: pip install pyjwt cryptography requests
"""
import os
import sys
import time

import jwt
import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'play'))
from whats_new import whats_new  # noqa: E402

API = 'https://api.appstoreconnect.apple.com/v1'
BUNDLE = 'com.dingo.duel'
GROUP = os.environ.get('BETA_GROUP', 'Friends')


def token():
    now = int(time.time())
    return jwt.encode(
        {'iss': os.environ['APPSTORE_ISSUER_ID'], 'iat': now, 'exp': now + 1100, 'aud': 'appstoreconnect-v1'},
        os.environ['APPSTORE_KEY'],
        algorithm='ES256',
        headers={'kid': os.environ['APPSTORE_KEY_ID'], 'typ': 'JWT'},
    )


def call(method, path, **kw):
    r = requests.request(method, API + path, headers={'Authorization': f'Bearer {token()}'}, timeout=60, **kw)
    if r.status_code >= 400:
        raise SystemExit(f'{method} {path}: {r.status_code} {r.text}')
    return r.json() if r.text else {}


def main():
    build_no = sys.argv[1] if len(sys.argv) > 1 else ''
    app = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]['id']
    params = {'filter[app]': app, 'sort': '-uploadedDate', 'limit': 1}
    if build_no:
        params['filter[version]'] = build_no
    # Wait for Apple to finish processing it (up to 40 minutes).
    for _ in range(80):
        builds = call('GET', '/builds', params=params)['data']
        if builds and builds[0]['attributes']['processingState'] == 'VALID':
            break
        state = builds[0]['attributes']['processingState'] if builds else 'not uploaded yet'
        print(f'Build {build_no or "(newest)"}: {state}; waiting…', flush=True)
        time.sleep(30)
    else:
        raise SystemExit('The build never finished processing.')
    build = builds[0]
    bid = build['id']
    print(f"Build {build['attributes']['version']} is ready.")

    groups = call('GET', '/betaGroups', params={'filter[app]': app, 'filter[name]': GROUP})['data']
    groups = [g for g in groups if not g['attributes'].get('isInternalGroup')]
    if not groups:
        raise SystemExit(f'No external TestFlight group called {GROUP}.')
    gid = groups[0]['id']

    # What to test: the same words as Play's "What's new".
    with open(os.path.join(os.path.dirname(__file__), '..', '..', 'lib', 'core', 'app_info.dart'), encoding='utf-8') as f:
        notes = whats_new(f.read())[:4000]
    locs = call('GET', f'/builds/{bid}/betaBuildLocalizations')['data']
    if locs:
        for loc in locs:
            call('PATCH', f"/betaBuildLocalizations/{loc['id']}", json={
                'data': {'type': 'betaBuildLocalizations', 'id': loc['id'], 'attributes': {'whatsNew': notes}}})
    else:
        call('POST', '/betaBuildLocalizations', json={'data': {
            'type': 'betaBuildLocalizations',
            'attributes': {'locale': 'en-US', 'whatsNew': notes},
            'relationships': {'build': {'data': {'type': 'builds', 'id': bid}}}}})

    call('POST', f'/betaGroups/{gid}/relationships/builds', json={'data': [{'type': 'builds', 'id': bid}]})
    print(f'Added to {GROUP}.')

    r = requests.post(API + '/betaAppReviewSubmissions', headers={'Authorization': f'Bearer {token()}'}, timeout=60,
                      json={'data': {'type': 'betaAppReviewSubmissions',
                                     'relationships': {'build': {'data': {'type': 'builds', 'id': bid}}}}})
    if r.status_code == 409:
        print('Already submitted for beta review (or approved).')
    elif r.status_code >= 400:
        raise SystemExit(f'Beta review submission: {r.status_code} {r.text}')
    else:
        print('Submitted for beta review: testers get it once Apple approves it.')


if __name__ == '__main__':
    main()
