import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_user/errands/api.dart';
import 'package:flutter_user/errands/drivers.dart';
import 'package:flutter_user/errands/errand.dart';
import 'package:flutter_user/errands/themehelper.dart';
import 'package:geolocator/geolocator.dart';

class ErrandHome extends StatefulWidget {
  const ErrandHome({super.key});

  @override
  State<ErrandHome> createState() => _ErrandHomeState();
}

class _ErrandHomeState extends State<ErrandHome> {

 bool loadPage = false;
 List Errands = [];

 getErrands() async{
  var response = await Api().getData("errands");
  var statusCode = response.statusCode;
  var body = jsonDecode(response.body);
  print(body);
  if(statusCode == 200){
    var status = body["status"];
      if(status == true){
        var errandRecords = body["errands"];
    setState(() {
      for(var errand in errandRecords){
        Errands.add(errand);
      }
      loadPage = true;
    });
      }
  }
 }

 checkErrands() async{
  var response = await Api().getData("checkerrands");
  var statusCode = response.statusCode;
  var body = jsonDecode(response.body);
  print(body);
  if(statusCode == 200){
    var status = body["status"];
    if(status == false){
      var message = body["message"];
      ScaffoldMessenger.of(context).showSnackBar(ThemeHelper().errorMessage(message));
    }else{
       Navigator.push(context,MaterialPageRoute(builder:(context) => const ErrandDrivers()));
    }
  }
 }




 @override
 initState(){
  super.initState();
  getErrands();
        Geolocator.checkPermission();
       Geolocator.requestPermission();
 }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar:AppBar(
        title:Text("Errands",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0)),
        centerTitle: true,
      ),
      drawer:Drawer(
        child: ListView(),
      ),
      body:loadPage == false ? ThemeHelper().pageLoader() : SafeArea(
        child: Container(
          padding:EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04,vertical: 20),
          child: ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Errand Records",style:TextStyle(fontWeight:FontWeight.bold)),
                  Container(
                    padding:const EdgeInsets.all(4.0),
                    decoration:const BoxDecoration(
                      shape:BoxShape.circle,
                      color:Colors.orange
                    ),
                    child: IconButton(onPressed: (){
                      checkErrands();
                    },icon:Icon(Icons.car_crash_sharp)))
                ],
              ),

              const SizedBox(height:30.0),
              Errands.isEmpty ? Container(
                padding:EdgeInsets.only(top:MediaQuery.of(context).size.height * 0.2),
                child: const Center(
                  child: Text("No Errand Record",style:TextStyle(fontWeight:FontWeight.bold)),
                ),
              ) : Column(
                children: Errands.map((data){
                  return GestureDetector(
                    onTap:(){
                      Navigator.push(context,MaterialPageRoute(builder:(context) => Errand(errandId:data["id"])));
                    },
                    child: Container(
                      padding:const EdgeInsets.symmetric(horizontal: 12.0,vertical: 10.0),
                      margin:const EdgeInsets.only(bottom:20.0),
                      decoration:BoxDecoration(
                        color:const Color(0xFFFFFFFF),
                        borderRadius:BorderRadius.circular(12.0),
                        boxShadow: const [
                          BoxShadow(color:Colors.grey,blurRadius: 2,offset:Offset(0,3)),
                           BoxShadow(color:Colors.grey,blurRadius: 2,offset:Offset(3,0)),
                        ]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              data["rider"] == null ? CircleAvatar(
                      radius:30.0,
                     backgroundImage: AssetImage("assets/errands/driver1.jpg"),           
                              ) : SizedBox()
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              data["rider"] == null ? const Text("Evans Stanley",style:TextStyle(fontWeight:FontWeight.bold)) : const SizedBox(),
                              data["rider"] == null ? const Text("Abj769689006",style:TextStyle(fontWeight:FontWeight.bold)) : const SizedBox(),
                              Text("Amount : N${data["estimated_purchase_amount"]}",style:const TextStyle(fontWeight:FontWeight.bold)),
                              data["errand_status"] == "pending" ? const Text("Pending",style:TextStyle(color:Colors.red)) : Text(data["errand_status"],style:TextStyle(color:Colors.green)),
                              data["errand_status"] == "pending" ? ElevatedButton(
                                style:ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  
                                ),
                                onPressed: () async{
                                var response = await Api().getData("cancelrequest/${data["id"]}");
                                var statusCode = response.statusCode;
                                var body = jsonDecode(response.body);
                                print(body);
                                if(statusCode == 200){
                                  var status = body["status"];
                                  if(status == true){
                                    setState(() {
                                      Errands.remove(data);
                                    });
                                  }
                                }
                              }, child:const Text("Cancel",style:TextStyle(color:Colors.white)) ) : const SizedBox()
                            ],
                          ),
                          data["errand_status"] != "pending" ? Column(
                            children: [
                              data["errand_status"] == "in process" ? IconButton(
                                onPressed:(){},icon:const Icon(Icons.message)
                              ) : const SizedBox()
                            ],
                          ) : const SizedBox()
                          ],
                      ),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
        ),
      )
    );
  }
}