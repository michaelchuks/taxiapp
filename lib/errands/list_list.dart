import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_user/errands/api.dart';
import 'package:flutter_user/errands/calculator.dart';
import 'package:flutter_user/errands/errandWidgets/button.dart';
import 'package:flutter_user/errands/errandWidgets/label_text.dart';
import 'package:flutter_user/errands/errandWidgets/textinput.dart';
import 'package:flutter_user/errands/errand_home.dart';
import 'package:flutter_user/errands/themehelper.dart';
import 'package:geolocator/geolocator.dart';

class ListList extends StatefulWidget {
  final dynamic riderId;
  final dynamic amount;
  const ListList({super.key,required this.amount,required this.riderId});

  @override
  State<ListList> createState() => _ListListState(amount,riderId);
}

class _ListListState extends State<ListList> {
  dynamic riderId;
  dynamic amount;
  _ListListState(this.amount,this.riderId);
  bool loadPage = false;
  List purchaseList = [];
  dynamic total;
  bool matchAmount = false;
  bool isLoading = false;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  showTotalWarning() async{
    await showModalBottomSheet(context: context, builder: (BuildContext context){
      return StatefulBuilder(builder: (BuildContext context,setstate){
        return Container(
          padding:EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04,vertical: 20.0),
          height:MediaQuery.of(context).size.height * 0.2,
          child: Column(
            children: [
              const Row(
                children: [Expanded(
                  child: Text("Your Purchase list total is more than your extimated purchase amount,click on the button below to change your purchase extimate to you list total"),
                )],
              ),
              Row(
                children: [
                  Switch(value: matchAmount, onChanged: (value){
                    setstate((){
                      matchAmount = value;
                    });
                  })
                ],
              )
            ],
          ),
        );
      });
    });
    setState(() {
      
    });
  }


  showList() async{
    await showModalBottomSheet(
      isDismissible: true,
      isScrollControlled: true,
      context: context, builder: (BuildContext context){
      return StatefulBuilder(builder: (BuildContext context,setstate){
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding:EdgeInsets.symmetric(horizontal:MediaQuery.of(context).size.width * 0.04,vertical:20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height:10.0,
                    width:MediaQuery.of(context).size.width * 0.5,
                     decoration:BoxDecoration(
                      borderRadius:BorderRadius.circular(10),
                      color:Colors.green
                     )
                  )
                  ],
              ),
              const SizedBox(height:20.0),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text("Enter purchase list item below",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0))
                ],
              ),

              const SizedBox(height:20.0),
              LabelText(text: "Product/Service Name"),
              TextInput(controller: nameController,hintText: "Produc/Service Name",keyboardType: TextInputType.text),

              LabelText(text: "Quantity"),
              TextInput(controller: quantityController,hintText: "Quantity",keyboardType: TextInputType.number),

              LabelText(text: "Estimated Amount"),
              TextInput(controller: amountController,hintText: "Estimated Amount",keyboardType: TextInputType.number),

              BigButton(context, text: "Add Item", isLoading: false, pressed: (){
                if(nameController.text == ""){
                  return false;
                }else if(quantityController.text == "" || int.parse(quantityController.text) < 1){
                  return false;
                }else if(amountController.text == ""){
                  return false;
                }else{
                  var item = {"name":nameController.text,"quantity":quantityController.text,"amount":amountController.text};
                  setstate((){
                    purchaseList.insert(0,item);
                  });
                   var purchaseTotal = 0;
                  for(var item in purchaseList){
                    purchaseTotal += int.parse(item["amount"]);
                  }

                  setstate((){
                    total = purchaseTotal;
                     nameController.clear();
                  quantityController.clear();
                  amountController.clear();
                  });

                 

                  Navigator.pop(context);
                }
              })
            ],
          ),
        );
      });
    });
    setState(() {
      
    });
  }


  submitErrandBooking() async{
    if(int.parse(amount) < total && matchAmount == false){
      showTotalWarning();
    }else{
       if(isLoading == true){
        return false;
       }else{
        setState(() {
          isLoading = true;
        });

         if(int.parse(amount) > total){
           setState((){
            amount = total;
           });
         }

           Geolocator.checkPermission();
       Geolocator.requestPermission();
       Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
       
       var data = {
        "purchase_list" : purchaseList,
        "driver_id" : riderId,
        "estimated_purchase_amount" : amount,
        "customer_longitude" : position.longitude.toString(),
        "customer_latitude" : position.latitude.toString(),
       };

       var response = await Api().postData(data, "initiateerrand");
       var statusCode = response.statusCode;
       var body = jsonDecode(response.body);
       print(body);
       if(statusCode == 200){
        var status = body["status"];
        if(status == true){
          var message = body["message"];
          ScaffoldMessenger.of(context).showSnackBar(ThemeHelper().successMessage(context,message , const ErrandHome()));
          Future.delayed(const Duration(seconds:3),(){
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(context) => const ErrandHome()), (route) => false);
          });
        }else{
          var message = body["message"];
          ScaffoldMessenger.of(context).showSnackBar(ThemeHelper().errorMessage(message));
        }
       }

        setState(() {
          isLoading = false;
        });
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
      appBar: AppBar(
        title:Text("Errand Details",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0)),
        centerTitle: true,
      ),

      body:loadPage == false ? ThemeHelper().pageLoader() : SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04,vertical: 20.0),
          child: ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Errand Purchase list"),
                  Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration:const BoxDecoration(
                      shape:BoxShape.circle,
                      color:Colors.orange
                    ),
                    child: IconButton(onPressed: (){
                      showList();
                    },icon: const Icon(Icons.add),),
                  )
                ],
              ),
              const SizedBox(height:20.0),
              purchaseList.isEmpty ? Container(
                padding:EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.3),
                child: const Center(
                  child: Text("No Purchase item"),
                ),
              ) : Column(
                children: purchaseList.map((data){
                  return Container(
                    padding:const EdgeInsets.symmetric(horizontal: 10.0,vertical: 6.0),
                    margin:const EdgeInsets.only(bottom:20.0),
                    decoration:BoxDecoration(
                      borderRadius:BorderRadius.circular(10.0),
                      color:const Color(0xFFFFFFFF),
                      boxShadow: const[
                        BoxShadow(color:Colors.grey,blurRadius: 3,offset:Offset(0,3))
                      ]
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(data["name"],style:TextStyle(fontWeight:FontWeight.bold)),)
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Quantity :",style:TextStyle(fontWeight:FontWeight.bold)),
                            Text(data["quantity"] + " Qty",style:TextStyle(fontWeight:FontWeight.bold))
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Amount :",style:TextStyle(fontWeight:FontWeight.bold)),
                            Text("N" + data["amount"],style:TextStyle(fontWeight:FontWeight.bold))
                          ],
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(onPressed:(){
                              setState(() {
                                purchaseList.remove(data);
                              });
                      var purchaseTotal = 0;
                  for(var item in purchaseList){
                    purchaseTotal += int.parse(item["amount"]);
                  }
                     setState(() {
                       total = purchaseTotal;
                     });
                            },icon:Icon(Icons.delete,color:Colors.red))
                          ],
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height:20.0),
             purchaseList.isEmpty ? SizedBox() : Container(
                padding:const EdgeInsets.symmetric(horizontal: 10.0,vertical: 20.0),
                decoration:BoxDecoration(
                  color:Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: const [
                    BoxShadow(color:Colors.grey,blurRadius: 3,offset:Offset(0,3)),
                    BoxShadow(color:Colors.grey,blurRadius: 3,offset:Offset(3,0))
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total",style:TextStyle(fontWeight:FontWeight.bold)),
                    Text("N$total",style:TextStyle(fontWeight:FontWeight.bold))
                  ],
                ),
              ),

              const SizedBox(height:20.0),

             purchaseList.isEmpty ? SizedBox() : BigButton(context, text: "Submit", isLoading: isLoading, pressed: (){
                submitErrandBooking();
              }),

              SizedBox(height:MediaQuery.of(context).size.height * 0.15)
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.only(right:30.0),
        height: MediaQuery.of(context).size.height * 0.1,
        child: Row(

          mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style:ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: (){
              Navigator.push(context,MaterialPageRoute(builder: (context) => Calculator()));
          }, child: const Text("open Calculator",style:TextStyle(color:Colors.black,fontWeight:FontWeight.bold)))
        ],),
      ),
    );
  }
}