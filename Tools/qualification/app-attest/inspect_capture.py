"""Inspect genuine local capture only. NOT a production/App Attest server verifier.
Requires cbor2==5.6.5 and cryptography. Never emits raw proofs, key IDs or receipts.
"""
import base64, hashlib, io, json, sys
from pathlib import Path
import cbor2
from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

root = Path(sys.argv[1])
app_id = 'ZEML4LPXH4.dev.djconnect.ios'
expected_rp = hashlib.sha256(app_id.encode()).digest()
def decode(data):
    stream = io.BytesIO(data)
    value = cbor2.CBORDecoder(stream).decode()
    assert stream.tell() == len(data), 'Trailing CBOR bytes'
    return value
def public_extensions(value):
    known = {'apple_validation_category_01', 'apple_bundle_version_01', 'validationCategory', 'bundleVersion'}
    return {str(k): ({'type':'bytes', 'hex':v.hex()} if isinstance(v,bytes) and str(k) in known
        else v if isinstance(v,(str,int,bool)) and str(k) in known else {'type':type(v).__name__}) for k,v in value.items()}
result = {'scope': 'genuine fixture structural and assertion-signature self-consistency; not qualified server verifier',
          'app_id': app_id, 'slots': {}, 'server_chain_receipt_policy': 'NOT_QUALIFIED_API_LANE_OWNS'}
for slot in ['active', 'replacement']:
    att = decode((root / f'{slot}-attestation.cbor').read_bytes())
    auth = att['authData']
    assert auth[:32] == expected_rp
    assert int.from_bytes(auth[33:37], 'big') == 0
    assert auth[32] & 0x40
    aaguid = auth[37:53]
    keylen = int.from_bytes(auth[53:55], 'big')
    credential = auth[55:55+keylen]
    # Check public-key ID binding, not certificate-chain trust.
    leaf = x509.load_der_x509_certificate(att['attStmt']['x5c'][0])
    public = leaf.public_key()
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    assert hashlib.sha256(public.public_bytes(Encoding.X962, PublicFormat.UncompressedPoint)).digest() == credential
    state = json.loads((root/'state.json').read_text())
    assert credential == base64.b64decode(state[slot])
    remainder = io.BytesIO(auth[55+keylen:])
    decoder = cbor2.CBORDecoder(remainder)
    cose = decoder.decode()
    extensions = decoder.decode() if auth[32] & 0x80 else {}
    assert remainder.tell() == len(auth[55+keylen:])
    counters=[]; assertion_extensions=[]
    indices = [i for i in range(1,6) if (root/f'{slot}-assert-{i}.cbor').exists()]
    assert indices in [[1,2], [1,2,3,4], [1,2,3,4,5]]
    for index in indices:
        obj = decode((root/f'{slot}-assert-{index}.cbor').read_bytes())
        data = obj['authenticatorData']; signature = obj['signature']
        assert data[:32] == expected_rp
        counter = int.from_bytes(data[33:37], 'big'); assert counter > (counters[-1] if counters else 0)
        counters.append(counter)
        ext = decode(data[37:]) if data[32] & 0x80 else {}
        assertion_extensions.append(ext)
        client = (root/f'{slot}-assert-{index}-input.bin').read_bytes()
        public.verify(signature, hashlib.sha256(data + hashlib.sha256(client).digest()).digest(), ec.ECDSA(hashes.SHA256()))
        try:
            public.verify(signature, hashlib.sha256(data + hashlib.sha256(client+b'tampered').digest()).digest(), ec.ECDSA(hashes.SHA256()))
        except InvalidSignature: pass
        else: raise AssertionError('Changed clientData accepted')
        changed_auth = bytearray(data); changed_auth[36] ^= 1
        try:
            public.verify(signature, hashlib.sha256(bytes(changed_auth) + hashlib.sha256(client).digest()).digest(), ec.ECDSA(hashes.SHA256()))
        except InvalidSignature: pass
        else: raise AssertionError('Changed signed counter accepted')
        other_slot = 'replacement' if slot == 'active' else 'active'
        other = decode((root/f'{other_slot}-attestation.cbor').read_bytes())
        wrong_public = x509.load_der_x509_certificate(other['attStmt']['x5c'][0]).public_key()
        try:
            wrong_public.verify(signature, hashlib.sha256(data + hashlib.sha256(client).digest()).digest(), ec.ECDSA(hashes.SHA256()))
        except InvalidSignature: pass
        else: raise AssertionError('Different key accepted')
    result['slots'][slot]={'format':att['fmt'], 'aaguid_hex':aaguid.hex(),
        'aaguid_ascii':aaguid.rstrip(b'\0').decode('ascii'), 'attestation_counter':0,
        'assertion_counters':counters, 'assertion_signatures_verified_against_leaf':True,
        'tampered_client_data_rejected':True, 'tampered_signed_counter_rejected':True, 'different_public_key_rejected':True, 'credential_matches_leaf_and_saved_handle':True,
        'attestation_extension_fields':public_extensions(extensions), 'assertion_extension_fields':[public_extensions(x) for x in assertion_extensions],
        'certificate_count':len(att['attStmt']['x5c']),
        'initial_receipt_present':bool(att['attStmt'].get('receipt'))}
# Different credentials demonstrate a replacement key, not backend revoke/repair.
state=json.loads((root/'state.json').read_text());assert state['active'] != state['replacement']
result['replacement_is_distinct']=True
boundary = root/'input-boundary-report.json'
if boundary.exists():
    observed = json.loads(boundary.read_text())
    unexpected = decode((root/'unexpected-hash-31.cbor').read_bytes())
    active_att = decode((root/'active-attestation.cbor').read_bytes())
    pub = x509.load_der_x509_certificate(active_att['attStmt']['x5c'][0]).public_key()
    data = unexpected['authenticatorData']
    pub.verify(unexpected['signature'], hashlib.sha256(data+bytes(31)).digest(), ec.ECDSA(hashes.SHA256()))
    result['sdk_hash_input_boundary'] = {
        'native_test': 'FAILED_ASSUMPTION_SDK_REQUIRES_32_BYTES',
        'observations': observed['errors'],
        'accepted_31_byte_hash_assertion_counter': int.from_bytes(data[33:37],'big'),
        'accepted_31_byte_hash_signature_verified': True,
        'subsequent_valid_assertion_counter': result['slots']['active']['assertion_counters'][-1],
        'counter_reset': False, 'new_keys_or_attestations': False}
print(json.dumps(result,indent=2))
