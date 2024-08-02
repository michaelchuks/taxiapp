
import "package:flutter/material.dart";
import "package:flutter_user/errands/themehelper.dart";



GestureDetector BigButton(BuildContext context,{required String text,required bool isLoading,required Function pressed}){
  return GestureDetector(
      onTap:(){
        pressed();
      },
    child: Container(
     // margin:EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.06,vertical: 10.0),
      padding:const EdgeInsets.only(top:18.0,bottom:18.0),
      width:double.maxFinite,
      decoration:BoxDecoration(
        color:const Color(0xFF208020),
        borderRadius:BorderRadius.circular(10.0),
        boxShadow: const [
          BoxShadow(color:Colors.grey,blurRadius: 7,offset: Offset(5,6))
        ]
      ),
    
      child:isLoading == false ? Text(text,style:const TextStyle(color:Color(0xFFEBFFFFFF),fontSize:14.0,fontWeight:FontWeight.w900),textAlign:TextAlign.center) : 
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ThemeHelper().buttonLoader() ,
          SizedBox(width:5.0),
           Text("loading ",style:const TextStyle(color:Color(0xFFEBFFFFFF),fontSize:14.0,fontWeight:FontWeight.w900),textAlign:TextAlign.center)
        ],
      )
    ),
  );
}