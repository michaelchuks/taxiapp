import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_user/errands/api.dart';
import 'package:flutter_user/errands/errandWidgets/button.dart';
import 'package:flutter_user/errands/errand_home.dart';
import 'package:flutter_user/errands/themehelper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import "package:http/http.dart" as http;

class ImageList extends StatefulWidget {
  final dynamic riderId;
  final dynamic amount;
  const ImageList({super.key,required this.amount,required this.riderId});

  @override
  State<ImageList> createState() => _ImageListState(amount,riderId);
}

class _ImageListState extends State<ImageList> {
  dynamic riderId;
  dynamic amount;
  _ImageListState(this.amount,this.riderId);
   bool isImageAdded = false;
  bool isLoading = false;

 File? _image;
 XFile? _imageFile;
 
 Uint8List? _newimageFile;
dynamic _pickedFile;
 Uint8List? displayImage;
 final _picker = ImagePicker();

  Future<void> _pickGallaryImage() async{
  _pickedFile = await _picker.pickImage(source: ImageSource.gallery,imageQuality: 50);
  _imageFile = await _picker.pickImage(source:  ImageSource.gallery);
  Uint8List img = await _imageFile!.readAsBytes();
  print(img);
  if(_pickedFile != null){
    setState(() {
      _image = File(_pickedFile!.path);
      isImageAdded = true;
      _newimageFile = img;
    });
  }else{
    setState(() {
      isImageAdded = false;
    });
  }
 }


  Future<void> _pickPhotoImage() async{
  _pickedFile = await _picker.pickImage(source: ImageSource.camera);
   _imageFile = await _picker.pickImage(source:  ImageSource.camera);
  Uint8List img = await _imageFile!.readAsBytes();
  if(_pickedFile != null){
    setState(() {
      _image = File(_pickedFile!.path);
      _newimageFile = img;
      isImageAdded = true;
    });
  }else{
    setState(() {
      isImageAdded  = false;
    });
  }
  }


  showImageUpload() {
    showModalBottomSheet(context: context, builder: (BuildContext context){
      return Container(
        height:MediaQuery.of(context).size.height * 0.2,
        padding:EdgeInsets.symmetric(vertical: 30.0,horizontal: 10.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Select From Gallary"),
                IconButton(onPressed: (){
                  _pickGallaryImage();
                }, icon:Icon(Icons.browse_gallery_sharp))
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Take A photo"),
                IconButton(onPressed: (){
                  _pickPhotoImage();
                }, icon:Icon(Icons.photo_camera))
              ],
            ),


          ],
        ),
      );
    });
  }


 


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
         title:Text("Errand Details",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0)),
        centerTitle: true,
      ),
      body:SafeArea(
        child: Container(
          padding:EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04,vertical: 20.0),
           child: ListView(
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Errand Purchase list image"),
                  Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration:const BoxDecoration(
                      shape:BoxShape.circle,
                      color:Colors.orange
                    ),
                    child: IconButton(onPressed: (){
                      showImageUpload();
                    },icon: const Icon(Icons.add),),
                  )
                ],
              ),
              const SizedBox(height:20.0),

                Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15.0),
                
              ),
              width:double.maxFinite,
              height:MediaQuery.of(context).size.height * 0.25,
              margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.02),
              child: _pickedFile != null ? Container(
                 height:MediaQuery.of(context).size.height * 0.8,
                 width:double.maxFinite,
                child:Image(image: MemoryImage(_newimageFile!),fit: BoxFit.cover,),
              ) : SizedBox()
            ),
            const SizedBox(height:30.0),
              _pickedFile != null ? BigButton(context, text: "Submit", isLoading: isLoading, pressed: () async{
                if(isLoading == true){
                  return false;
                }else{
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                  Map errandDetails = {"rider_id":riderId,"amount":amount,"longitude":position.longitude,"latitude":position.latitude};
                  setState((){
                    isLoading = true;
                  });

                 http.StreamedResponse response = await Api().uploadListImage(_pickedFile,errandDetails,"initiateerrand");
                   if(response.statusCode == 200){
                    Map map = jsonDecode(await response.stream.bytesToString());
                    print(map);
                    var status = map["status"];
                    if(status == true){
                      var message = map["message"];
                      ScaffoldMessenger.of(context).showSnackBar(ThemeHelper().errorMessage(message));
                       Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(context) => ErrandHome()), (route) => false);
                    }
                   }else{
                      Map map = jsonDecode(await response.stream.bytesToString());
                    print(map);
                   }

                  setState(() {
                    isLoading = false;
                  });
                }
              }) : const SizedBox()
            ],
           ),
        ),
      )
    );
  }
}