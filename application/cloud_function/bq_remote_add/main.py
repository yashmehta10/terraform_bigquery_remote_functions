from flask import jsonify

def batch_add(request):
    try:
        return_value = []
        request_json = request.get_json()
        print(request_json)
        calls = request_json['calls']
        for call in calls:
            return_value.append(int(call[0])+1)
        return_json = jsonify( { "replies":  return_value } )
        return return_json
        
    except Exception as e:
        return jsonify( { "errorMessage": str(e) } ), 400