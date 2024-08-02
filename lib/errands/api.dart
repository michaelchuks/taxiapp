import "dart:convert";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:shared_preferences/shared_preferences.dart";
import "dart:io";




class Api{
 

  static const header1 = {
      "accept" : "applcation/json",
     'Content-Type': 'application/json;charset=UTF-8',
    
  };

   //String baseUrl = "https://dton.ng/api/";
   String baseUrl = "http://10.0.2.2:8000/api/";

  getData(String endpoint) async{
  final  response = await http.get(Uri.parse(baseUrl+endpoint),headers: header1);
  return response;
  }

  postData(Map data,String endpoint) async{
      var header = {
        "accept" : "applcation/json",
    "Content-type" : "application/json"
  };
  final response = await http.post(Uri.parse(baseUrl+endpoint),headers: header,body:jsonEncode(data));
  return response;
  }


   postAuthData(Map data,String endpoint) async{
     SharedPreferences userdetails = await SharedPreferences.getInstance();
     var token = userdetails.getString("token");
     var header = {
      "accept" : "applcation/json",
    "Content-type" : "application/json",
    "Authorization" : " Bearer $token"
  };

    final response = await http.post(Uri.parse(baseUrl+endpoint),headers: header,body:jsonEncode(data));
    return response;
   }


     getAuthData(String endpoint) async{
     SharedPreferences userdetails = await SharedPreferences.getInstance();
     var token = userdetails.getString("token");
     var header = {
       "accept" : "applcation/json",
    "Content-type" : "application/json;charset=UTF-8",
    "Authorization" : " Bearer $token"
  };

    final response = await http.get(Uri.parse(baseUrl+endpoint),headers: header);
    return response;
   }

    


    Future<http.StreamedResponse> uploadListImage(dynamic data,Map errandDetails,String endpoint,)async{
       //SharedPreferences userdetails = await SharedPreferences.getInstance();
     //var token = userdetails.getString("token");
     http.MultipartRequest request = http.MultipartRequest("POST",Uri.parse(baseUrl+endpoint));
     request.fields["driver_id"] = errandDetails["rider_id"].toString();
     request.fields["estimated_purchase_amount"] = errandDetails["amount"].toString();
     request.fields["customer_longitude"] = errandDetails["longitude"].toString();
     request.fields["customer_latitude"] = errandDetails["latitude"].toString();
     //request.headers.addAll(<String,String>{"Authorization" : "Bearer $token"});
     File _file = File(data!.path);
     request.files.add(http.MultipartFile('image',_file.readAsBytes().asStream(),_file.lengthSync(),filename: _file.path.split('/').last));
     http.StreamedResponse response = await request.send();
     return response;

   
   }


    Future<http.StreamedResponse> uploadImage2(PickedFile? data, String endpoint)async{
       SharedPreferences userdetails = await SharedPreferences.getInstance();
     var token = userdetails.getString("token");
     http.MultipartRequest request = http.MultipartRequest("POST",Uri.parse(baseUrl+endpoint));
        request.headers.addAll(<String,String>{"Authorization" : "Bearer $token"});
     File _file = File(data!.path);
     request.files.add(http.MultipartFile('image',_file.readAsBytes().asStream(),_file.lengthSync(),filename: _file.path.split('/').last));
     http.StreamedResponse response = await request.send();
     return response;

   
   }


      Future<http.StreamedResponse> uploadStaffImage(PickedFile? data, String endpoint,dynamic staffId)async{
       SharedPreferences userdetails = await SharedPreferences.getInstance();
     var token = userdetails.getString("token");
     http.MultipartRequest request = http.MultipartRequest("POST",Uri.parse(baseUrl+endpoint));
     request.fields["staff_id"] = staffId.toString();
      request.headers.addAll(<String,String>{"Authorization" : "Bearer $token"});
     File _file = File(data!.path);
     request.files.add(http.MultipartFile('image',_file.readAsBytes().asStream(),_file.lengthSync(),filename: _file.path.split('/').last));
     http.StreamedResponse response = await request.send();
     return response;

   
   }



}