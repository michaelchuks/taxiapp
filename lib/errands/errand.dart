import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_user/errands/api.dart";
import "package:flutter_user/errands/themehelper.dart";

class Errand extends StatefulWidget{
  final dynamic errandId;
  const Errand({super.key,required this.errandId});

  State<Errand> createState() => _ErrandState(errandId);
}



class _ErrandState extends State<Errand>{
  dynamic errandId;
  _ErrandState(this.errandId);
  bool loadPage = false;
  Map? errand;
  Map? driver;

 getErrand() async{
  var response = await Api().getData("errand/$errandId");
  var statusCode = response.statusCode;
  var body = jsonDecode(response.body);
  if(statusCode == 200){
    var status = body["status"];
    if(status == true){
      var returnedErrand = body["errand"];
       setState(() {
         errand = returnedErrand;
         loadPage = true;
       });
    }
  }
 }


 @override
 void initState() {
    super.initState();
    getErrand();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(
        title:Text("Errand Details",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0)),
       centerTitle : true
      ),

      body:loadPage == false ? ThemeHelper().pageLoader() : SafeArea(
        child: Container(
          padding:EdgeInsets.symmetric(horizontal:MediaQuery.of(context).size.width * 0.04),
          child:ListView(
            children: [

            ],
          )
        ),
      )
    );
  }
}