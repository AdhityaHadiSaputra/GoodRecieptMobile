import 'dart:convert';
import 'package:http/http.dart' as http;

class APIUrl{
  static String BASE_URL = 'http://108.136.252.63:8080/pogr';
  static String LOGIN_URL = '$BASE_URL/login.php';
  static String PO_URL = '$BASE_URL/cekpo.php';
  static String MASTER_URL = '$BASE_URL/getmaster.php';
}


class ApiService {
  Future<Map<String, dynamic>> loginUser(
      String USERID, String USERPASSWORD) async {
    try {
      final response = await http.post(
        Uri.parse(APIUrl.LOGIN_URL),
        body: {
          'ACTION': 'LOGIN',
          'USERID': USERID,
          'USERPASSWORD': USERPASSWORD,
        },
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        return result;
      } else {
        throw Exception('Failed to login');
      }
    } catch (error) {
      print('Error: $error');
      rethrow;
    }
  }
}

class Apiuser {
 
  Future<Map<String, dynamic>> fetchPO(String PONO) async {
    try {
      final response = await http.post(
        Uri.parse(APIUrl.PO_URL),
        body: {
          'ACTION': 'GETPO',
          'PONO': PONO,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load PO data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}

class ApiMaster{
  Future<Map<String, dynamic>> fetchMaster(String BRAND) async{
    try{
    final response = await http.post(
      Uri.parse(APIUrl.MASTER_URL),
      body: {
        'ACTION': 'GETITEM',
        'BRAND': 'YEC'
      },
    );
    if(response.statusCode == 200){
      return json.decode(response.body) as Map<String, dynamic>;
    }else{
      throw Exception('Failed to load Master Data');
    }
    } catch (e){
      throw Exception('Error: $e');
    }
  }
}