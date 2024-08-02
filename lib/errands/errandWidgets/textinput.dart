import 'package:flutter/material.dart';

// ignore: non_constant_identifier_names
Container TextInput({TextEditingController? controller,TextInputType? keyboardType,String? hintText}){
  return Container(
    height:60.0,
    margin:const EdgeInsets.only(bottom:30.0),
     padding:const EdgeInsets.only(left:10.0,top:10.0,right:10.0,bottom: 10),
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(10.0),
      color:Color(0xFFF0F0F0)
     
    ),
    child: TextFormField(
      keyboardType:keyboardType,
      controller: controller,
       style:TextStyle(color:Color(0xFF000000),fontWeight: FontWeight.w500,fontSize:14.0,letterSpacing: 1.0),
      decoration:InputDecoration(
        border:InputBorder.none,
        hintText: hintText,
        hintStyle: TextStyle(fontSize:15.0,letterSpacing: 1.0)
      ),
   
  ),
  )
  ;
}