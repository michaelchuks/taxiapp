import "package:flutter/material.dart";
import 'package:flutter_spinkit/flutter_spinkit.dart';


class ThemeHelper{

   SnackBar errorMessage(String? message){
    return SnackBar(content:Text("$message",style:const TextStyle(
      color:Colors.white
    )));
   }


   SnackBar successMessage(BuildContext context,String? message,Widget route){
    return SnackBar(content:Text("$message"),
    duration: const Duration(days:365),
    action: SnackBarAction(
      label:"ok",
      onPressed: (){
        Navigator.push(context,MaterialPageRoute(builder:(context) => route ));
      },
    ),
    );
   }


 Center pageLoader(){
    return const Center(
      child: SpinKitDualRing(
        color:Colors.orange,
        size:50.0

      ),
    );
 }



  Center buttonLoader(){
    return const Center(
      child: SpinKitDualRing(
        color:Color(0xFFEBFFFFFF),
        size:20.0

      ),
    );
 }


}