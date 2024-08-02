import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_user/errands/errand_booking.dart';
import 'package:flutter_user/errands/themehelper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class ErrandDrivers extends StatefulWidget {
  const ErrandDrivers({super.key});

  @override
  State<ErrandDrivers> createState() => _ErrandDriversState();
}

class _ErrandDriversState extends State<ErrandDrivers> {
bool loadPage = false;
double? longitude1;
double? latitude1;
List drivers = [
  {"id":2,"name":"Evans Stanley","plate_number":"BNG236789","current_location":"Nyanya Mall","distance":10,"longitude":0.34,"latitude":0.78,"image":"assets/errands/driver1.jpg"},
   {"id":5,"name":"Uche Melody","plate_number":"XYT8907RC","current_location":"Kugbo Furnitures","distance":20,"longitude":0.89,"latitude":0.1,"image":"assets/errands/driver2.jpg"},
];

 LatLng? startPosition;

 setInitialPosition() async{
   Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

   setState(() {
     startPosition = LatLng(position.latitude.toDouble(),position.longitude.toDouble());
     latitude1 = position.latitude.toDouble();
     longitude1 = position.longitude.toDouble();
   });
 }


 @override
 void initState() {
    // TODO: implement initState
    super.initState();
    setInitialPosition();

  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title:Text("Available Riders",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0)),
        centerTitle: true,
      ),

      body:SafeArea(
        child:startPosition == null ? ThemeHelper().pageLoader() : GoogleMap(
          initialCameraPosition: CameraPosition(target:startPosition!,zoom: 13),
          markers: {
            Marker(
              onTap:(){
                 Navigator.push(context,MaterialPageRoute(builder:(context) => ErrandBooking(riderId: drivers[1]["id"], rider: drivers[1])));
              },
              markerId: MarkerId("1"),
              position: startPosition!,
              icon:BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: "My Position"
              ) 
            ),

             Marker(
              onTap:(){
                 Navigator.push(context,MaterialPageRoute(builder:(context) => ErrandBooking(riderId: drivers[0]["id"], rider: drivers[0])));
              },
              markerId: MarkerId("2"),
              position: LatLng(latitude1!+drivers[0]["latitude"].toDouble(),longitude1! + drivers[0]["longitude"].toDouble()),
              icon:BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: drivers[0]["name"]
              ) 
            ),

             Marker(
              onTap: (){
                Navigator.push(context,MaterialPageRoute(builder:(context) => ErrandBooking(riderId: drivers[1]["id"], rider: drivers[1])));
              },
              markerId: MarkerId("1"),
              position:startPosition!, //LatLng(latitude1! + drivers[1]["latitude"].toDouble(),longitude1!+drivers[1]["longitude"].toDouble()),
              icon:BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: drivers[1]["name"]
              ) 
            ),



          },
          )
        
        /*Container(
          padding:EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04,vertical: 30.0),
          child: ListView(
            children: [
              const Row(children: [
                Text("Click To Book Rider For Errands",style:TextStyle(fontWeight:FontWeight.bold))
              ],),
              const SizedBox(height:30.0),
              Column(
                children: drivers.map((driver){
                  return GestureDetector(
                    onTap:(){
                      Navigator.push(context,MaterialPageRoute(builder:(context) => ErrandBooking(riderId: driver["id"].toString())));
                    },
                    child: Container(
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
                                backgroundImage: AssetImage(driver["image"]),
                                ),
                                Text(driver["name"],style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14.0)),
                                 Text("Plate No : " +driver["plate_number"],style:TextStyle(fontWeight:FontWeight.bold))
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                             Row(
                              children: [
                                const Icon(Icons.location_city),
                                Text(driver["current_location"],style:TextStyle(fontWeight:FontWeight.bold))
                              ],
                             ),
                             Row(
                               children: [
                                const Icon(Icons.speed),
                                 Text(driver["distance"].toString() + "KM",style:TextStyle(fontWeight:FontWeight.bold)),
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
                  );
                }).toList(),
              ),
            ],
          ),
        ),*/
      )
    
    );
  }
}