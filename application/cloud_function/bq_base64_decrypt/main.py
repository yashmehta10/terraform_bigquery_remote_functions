from flask import jsonify
import base64

def decrypt(message):
	return base64.b64decode(message.encode("ascii")).decode("ascii")

def accept_request(request):
    request_json = request.get_json()
    calls = request_json['calls']
    return_value = []
    try:
        for call in calls:
            print(call)
            return_value.append(decrypt(call[0]))
            return_json = jsonify( { "replies":  return_value } )
        return return_json
    except Exception as e:
        return jsonify( { "errorMessage": str(e) } ), 400