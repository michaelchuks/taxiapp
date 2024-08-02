import 'package:flutter/material.dart';
import 'package:flutter_user/errands/document_list.dart';
import 'package:flutter_user/errands/errandWidgets/button.dart';
import 'package:flutter_user/errands/errandWidgets/textinput.dart';
import 'package:flutter_user/errands/image_list.dart';
import 'package:flutter_user/errands/list_list.dart';
import 'package:flutter_user/errands/themehelper.dart';

class ErrandBooking extends StatefulWidget {
  final dynamic riderId;
  final Map rider;
  const ErrandBooking({super.key,required this.riderId,required this.rider});

  @override
  State<ErrandBooking> createState() => _ErrandBookingState(riderId,rider);
}

class _ErrandBookingState extends State<ErrandBooking> {
  dynamic riderId;
  Map? rider;
  _ErrandBookingState(this.riderId,this.rider);
  final TextEditingController amountController = TextEditingController();
  bool loadPage = false;
  List listType = [
    "Select Product List Upload Method","image","list"
  ];
  dynamic productListMethod = "Select Product List Upload Method";

  redirect(){
   if(amountController.text == ""){
    ScaffoldMessenger.of(context).showSnackBar(ThemeHelper().errorMessage("Please enter estimated amount for purchase"));
   }else if(productListMethod == "Select Product List Upload Method"){
     ScaffoldMessenger.of(context).showSnackBar(ThemeHelper().errorMessage("select product list upload method"));
   }else{
     if(productListMethod == "image"){
      Navigator.push(context,MaterialPageRoute(builder:(context) => ImageList(amount: amountController.text, riderId: riderId)));
    }else if(productListMethod == "list"){
       Navigator.push(context,MaterialPageRoute(builder:(context) => ListList(amount: amountController.text, riderId: riderId)));
    }else if(productListMethod == "document"){
       Navigator.push(context,MaterialPageRoute(builder:(context) => DocumentList(amount: amountController.text, riderId: riderId)));
    }
   }
  }
 
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds:3),(){
      setState(() {
        loadPage = true;
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title:const Text("Errand Details",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0)),
        centerTitle: true,
      ),

      body:loadPage == false ? ThemeHelper().pageLoader() : SafeArea(
        child: Container(
          padding:EdgeInsets.symmetric(horizontal:MediaQuery.of(context).size.width* 0.04,vertical:30.0),
          child: ListView(
            children: [
              const SizedBox(
                height:10.0
              ),
           

             Container(
                      margin:const EdgeInsets.only(bottom:20.0),
                      padding:const EdgeInsets.symmetric(horizontal: 10.0,vertical: 6.0),
                      decoration:BoxDecoration(
                        borderRadius:BorderRadius.circular(12.0),
                        color:const Color(0xFFFFFFFF),
                        boxShadow: const [
                          BoxShadow(color:Colors.grey,blurRadius: 3,offset:Offset(0,3)),
                          BoxShadow(color:Colors.grey,blurRadius: 3,offset:Offset(3,0)),
                        ]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius:22,
                                backgroundImage: AssetImage(rider!["image"]),
                                ),
                                Text(rider!["name"],style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14.0)),
                                 Text("Plate No : " +rider!["plate_number"],style:TextStyle(fontWeight:FontWeight.bold))
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                             Row(
                              children: [
                                const Icon(Icons.location_city),
                                Text(rider!["current_location"],style:TextStyle(fontWeight:FontWeight.bold))
                              ],
                             ),
                             Row(
                               children: [
                                const Icon(Icons.speed),
                                 Text(rider!["distance"].toString() + "KM",style:TextStyle(fontWeight:FontWeight.bold)),
                               ],
                             ),
                             const Text("Available",style:TextStyle(color:Colors.orange,fontWeight:FontWeight.bold)),
                            const  Row(
                              children: [
                                Icon(Icons.star,color:Colors.orange),
                                Icon(Icons.star,color:Colors.orange),
                                Icon(Icons.star,color:Colors.orange),
                                Icon(Icons.star,color:Colors.orange)
                              ],
                             )
                            ],
                          ),
                         
                        ],
                      ),
                    ),

              const SizedBox(height:20.0),
               const Row(
                children: [
                  Expanded(
                    child: Text("Enter Your Errand details below, your estimated purchase amount will be deducted and moved into the rider's wallet",style:TextStyle(fontWeight:FontWeight.bold)),
                  )
                ],
              ),

              const SizedBox(height: 20.0),
               const Row(
                children: [
                Text("Amount",style:TextStyle(color:Colors.grey,fontWeight:FontWeight.bold,fontSize:14.0))
               ],),
              TextInput(controller:amountController,hintText: "Estimated Amount for purchase/products payment",keyboardType: TextInputType.number),


              Container(
             height:60.0,

    margin:const EdgeInsets.only(bottom:30.0,top:20.0),
     padding:const EdgeInsets.only(left:10.0,top:10.0,right:10.0,bottom: 10),
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(10.0),
      color:Color(0xFFF0F0F0)
     
    ),
          width:double.maxFinite,
         
          child: DropdownButtonHideUnderline(
            child: DropdownButton(
              value:productListMethod,
              onChanged: (value){
                  setState(() {
                    productListMethod = value;
                  });
                
              },
              items:listType.map((data){
                return DropdownMenuItem(child: Text(data),value:data);
              }).toList()
            ),
          )
        ),

        const SizedBox(height:20.0),

        BigButton(context, text: "Proceed", isLoading: false, pressed: (){
          redirect();
        })
            ],
          ),
        ),
      ),
 
    );
  }
}