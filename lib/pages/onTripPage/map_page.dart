import 'dart:math';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_user/pages/onTripPage/ongoingrides.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'dart:ui' as ui;
import '../../functions/functions.dart';
import '../../functions/geohash.dart';
import '../../functions/notifications.dart';
import '../../styles/styles.dart';
import '../../translations/translation.dart';
import '../../widgets/widgets.dart';
import '../NavigatorPages/notification.dart';
import '../loadingPage/loading.dart';
import '../login/login.dart';
import '../navDrawer/nav_drawer.dart';
import 'package:geolocator/geolocator.dart' as geolocs;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:vector_math/vector_math.dart' as vector;
import '../noInternet/noInternet.dart';
import 'booking_confirmation.dart';
import 'drop_loc_select.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
// ignore: depend_on_referenced_packages
import 'package:latlong2/latlong.dart' as fmlt;

class Maps extends StatefulWidget {
  const Maps({super.key});

  @override
  State<Maps> createState() => _MapsState();
}

dynamic serviceEnabled;
dynamic currentLocation;
LatLng center = const LatLng(41.4219057, -102.0840772);
String mapStyle = '';
List myMarkers = [];
Set<Marker> markers = {};
String dropAddressConfirmation = '';
List<AddressList> addressList = <AddressList>[];
dynamic favLat;
dynamic favLng;
String favSelectedAddress = '';
String favName = 'Home';
String favNameText = '';
bool requestCancelledByDriver = false;
bool cancelRequestByUser = false;
bool logout = false;
bool deleteAccount = false;
int choosenTransportType =
    (userDetails['enable_modules_for_applications'] == 'both' ||
            userDetails['enable_modules_for_applications'] == 'taxi')
        ? 0
        : 1;
String transportType = 'Taxi';

class _MapsState extends State<Maps>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // dynamic _currentCenter;
  dynamic _lastCenter;
  LatLng _centerLocation = const LatLng(41.4219057, -102.0840772);
  final _debouncer = Debouncer(milliseconds: 1000);

  bool ischanged = false;

  dynamic animationController;
  dynamic _sessionToken;
  bool _loading = false;
  bool _pickaddress = false;
  bool _dropaddress = false;
  final bool _dropLocationMap = false;
  bool _locationDenied = false;
  int gettingPerm = 0;
  Animation<double>? _animation;

  late geolocs.LocationPermission permission;
  Location location = Location();
  String state = '';
  dynamic _controller;
  final fm.MapController _fmController = fm.MapController();
  Map myBearings = {};

  dynamic pinLocationIcon;
  dynamic deliveryIcon;
  dynamic bikeIcon;
  dynamic userLocationIcon;
  bool favAddressAdd = false;
  bool contactus = false;
  bool _isDarkTheme = false;
  List gesture = [];
  dynamic start;
  final _mapMarkerSC = StreamController<List<Marker>>();
  StreamSink<List<Marker>> get _mapMarkerSink => _mapMarkerSC.sink;
  Stream<List<Marker>> get carMarkerStream => _mapMarkerSC.stream;

  dynamic _height = 0;
  dynamic _outstationheight = 0;
  double _isbottom = -1000;

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _controller = controller;
      _controller?.setMapStyle(mapStyle);
    });
  }

  late final AnimationController _animationcontroller = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: MyTickerProvider(),
  )..repeat(reverse: true);
  late final Animation<Offset> _offsetAnimation = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(2.5, 0.0),
  ).animate(CurvedAnimation(
    parent: _animationcontroller,
    curve: Curves.linear,
  ));

  @override
  void initState() {
    _isDarkTheme = isDarkTheme;
    WidgetsBinding.instance.addObserver(this);
    choosenTransportType =
        (userDetails['enable_modules_for_applications'] == 'both' ||
                userDetails['enable_modules_for_applications'] == 'taxi')
            ? 0
            : 1;

    getLocs();
    getadminCurrentMessages();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _controller?.setMapStyle(mapStyle);
      }
      if (locationAllowed == true) {
        if (positionStream == null || positionStream!.isPaused) {
          positionStreamData();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    animationController?.dispose();
    _animationcontroller.dispose();
    super.dispose();
  }

  navigateLogout() {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false);
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

//navigate
  navigate() {
    ismulitipleride = false;

    if (choosenTransportType == 0) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => BookingConfirmation()),
          (route) => false);
    } else if (choosenTransportType == 1) {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => DropLocation()));
    }
  }

//get location permission and location details
  getLocs() async {
    myBearings.clear;
    addressList.clear();
    serviceEnabled = await location.serviceEnabled();
    polyline.clear();
    final Uint8List markerIcon =
        await getBytesFromAsset('assets/images/top-taxi.png', 40);
    pinLocationIcon = BitmapDescriptor.fromBytes(markerIcon);
    final Uint8List deliveryIcons =
        await getBytesFromAsset('assets/images/deliveryicon.png', 40);
    deliveryIcon = BitmapDescriptor.fromBytes(deliveryIcons);
    final Uint8List bikeIcons =
        await getBytesFromAsset('assets/images/bike.png', 40);
    bikeIcon = BitmapDescriptor.fromBytes(bikeIcons);

    permission = await geolocs.GeolocatorPlatform.instance.checkPermission();

    if (permission == geolocs.LocationPermission.denied ||
        permission == geolocs.LocationPermission.deniedForever ||
        serviceEnabled == false) {
      gettingPerm++;

      if (gettingPerm > 1 || locationAllowed == false) {
        state = '3';
        locationAllowed = false;
      } else {
        state = '2';
      }
      _loading = false;
      setState(() {});
    } else {
      var locs = await geolocs.Geolocator.getLastKnownPosition();
      if (locs != null) {
        setState(() {
          center = LatLng(double.parse(locs.latitude.toString()),
              double.parse(locs.longitude.toString()));
          _centerLocation = LatLng(double.parse(locs.latitude.toString()),
              double.parse(locs.longitude.toString()));
          currentLocation = LatLng(double.parse(locs.latitude.toString()),
              double.parse(locs.longitude.toString()));
          _lastCenter = _centerLocation;
        });
      } else {
        var loc = await geolocs.Geolocator.getCurrentPosition(
            desiredAccuracy: geolocs.LocationAccuracy.low);
        setState(() {
          center = LatLng(double.parse(loc.latitude.toString()),
              double.parse(loc.longitude.toString()));
          _centerLocation = LatLng(double.parse(loc.latitude.toString()),
              double.parse(loc.longitude.toString()));
          currentLocation = LatLng(double.parse(loc.latitude.toString()),
              double.parse(loc.longitude.toString()));
          _lastCenter = _centerLocation;
        });
      }

      // _centerLocation = center;
      _lastCenter = _centerLocation;

      setState(() {
        locationAllowed = true;
        state = '3';
        _loading = false;
      });
      if (locationAllowed == true) {
        if (positionStream == null || positionStream!.isPaused) {
          positionStreamData();
        }
      }
    }
  }

  getLocationPermission() async {
    if (permission == geolocs.LocationPermission.denied ||
        permission == geolocs.LocationPermission.deniedForever) {
      if (permission != geolocs.LocationPermission.deniedForever) {
        await perm.Permission.location.request();
      }
      if (serviceEnabled == false) {
        await geolocs.Geolocator.getCurrentPosition(
            desiredAccuracy: geolocs.LocationAccuracy.low);
        // await location.requestService();
      }
    } else if (serviceEnabled == false) {
      await geolocs.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocs.LocationAccuracy.low);
      // await location.requestService();
    }
    setState(() {
      _loading = true;
    });
    getLocs();
  }

  int _bottom = 0;

  GeoHasher geo = GeoHasher();

  @override
  Widget build(BuildContext context) {
    double lat = 0.0144927536231884;
    double lon = 0.0181818181818182;
    double lowerLat = center.latitude - (lat * 1.24);
    double lowerLon = center.longitude - (lon * 1.24);

    double greaterLat = center.latitude + (lat * 1.24);
    double greaterLon = center.longitude + (lon * 1.24);
    var lower = geo.encode(lowerLon, lowerLat);
    var higher = geo.encode(greaterLon, greaterLat);

    var fdb = FirebaseDatabase.instance
        .ref('drivers')
        .orderByChild('g')
        .startAt(lower)
        .endAt(higher);

    var media = MediaQuery.of(context).size;
    popFunction() {
      if (_bottom == 1) {
        return false;
      } else {
        return true;
      }
    }

    return PopScope(
      canPop: popFunction(),
      onPopInvoked: (did) {
        if (_bottom == 1) {
          setState(() {
            _height = media.width * 0.68;
            _bottom = 0;
            if (choosenTransportType == 2) {
              choosenTransportType = 0;
            }
          });
        }
      },
      child: SafeArea(
        child: Material(
          child: ValueListenableBuilder(
              valueListenable: valueNotifierHome.value,
              builder: (context, value, child) {
                if (_isDarkTheme != isDarkTheme && _controller != null) {
                  _controller!.setMapStyle(mapStyle);
                  _isDarkTheme = isDarkTheme;
                }
                if (isGeneral == true) {
                  isGeneral = false;
                  if (lastNotification != latestNotification) {
                    lastNotification = latestNotification;
                    pref.setString('lastNotification', latestNotification);
                    latestNotification = '';
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const NotificationPage()));
                    });
                  }
                }

                return Directionality(
                  textDirection: (languageDirection == 'rtl')
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Scaffold(
                    resizeToAvoidBottomInset: false,
                    drawer: const NavDrawer(),
                    body: Stack(
                      children: [
                        Container(
                          color: page,
                          height: media.height * 1,
                          width: media.width * 1,
                          child: Column(
                              mainAxisAlignment: (state == '1' || state == '2')
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                (state == '1')
                                    ? Container(
                                        height: media.height * 0.96,
                                        width: media.width * 1,
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: EdgeInsets.all(
                                              media.width * 0.05),
                                          width: media.width * 0.6,
                                          height: media.width * 0.3,
                                          decoration: BoxDecoration(
                                              color: page,
                                              boxShadow: [
                                                BoxShadow(
                                                    blurRadius: 5,
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    spreadRadius: 2)
                                              ],
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                languages[choosenLanguage]
                                                    ['text_enable_location'],
                                                style: GoogleFonts.notoSans(
                                                    fontSize:
                                                        media.width * sixteen,
                                                    color: textColor,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Container(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      state = '';
                                                    });
                                                    getLocs();
                                                  },
                                                  child: Text(
                                                    languages[choosenLanguage]
                                                        ['text_ok'],
                                                    style: GoogleFonts.notoSans(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: media.width *
                                                            twenty,
                                                        color: buttonColor),
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      )
                                    : (state == '2')
                                        ? Container(
                                            height: media.height * 0.96,
                                            width: media.width * 1,
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                    child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.31,
                                                      child: Image.asset(
                                                        'assets/images/location_perm.png',
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.02,
                                                    ),
                                                    MyText(
                                                      text: languages[
                                                              choosenLanguage][
                                                          'text_allowpermission1'],
                                                      size: media.width *
                                                          eighteen,
                                                      textAlign:
                                                          TextAlign.center,
                                                      fontweight:
                                                          FontWeight.bold,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.04,
                                                    ),
                                                    MyText(
                                                      text: languages[
                                                              choosenLanguage][
                                                          'text_allowpermission2'],
                                                      size:
                                                          media.width * sixteen,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.04,
                                                    ),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          height: media.width *
                                                              0.07,
                                                          width: media.width *
                                                              0.07,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Colors.red
                                                                  .withOpacity(
                                                                      0.1)),
                                                          child: const Icon(
                                                            Icons
                                                                .location_on_outlined,
                                                            color: Color(
                                                                0xFFFF0000),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                            width: media.width *
                                                                0.02),
                                                        MyText(
                                                          text: languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_loc_permission_user'],
                                                          size: media.width *
                                                              sixteen,
                                                          fontweight:
                                                              FontWeight.bold,
                                                        )
                                                      ],
                                                    ),
                                                  ],
                                                )),
                                                Container(
                                                    padding: EdgeInsets.all(
                                                        media.width * 0.05),
                                                    child: Button(
                                                        onTap: () async {
                                                          getLocationPermission();
                                                        },
                                                        text: languages[
                                                                choosenLanguage]
                                                            ['text_next']))
                                              ],
                                            ),
                                          )
                                        : (state == '3')
                                            ? Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  SizedBox(
                                                      height:
                                                          media.height * 0.96,
                                                      width: media.width * 1,
                                                      child: StreamBuilder<
                                                              DatabaseEvent>(
                                                          stream: fdb.onValue,
                                                          builder: (context,
                                                              AsyncSnapshot<
                                                                      DatabaseEvent>
                                                                  event) {
                                                            if (event.hasData) {
                                                              List driverData =
                                                                  [];
                                                              event
                                                                  .data!
                                                                  .snapshot
                                                                  .children
                                                                  // ignore: avoid_function_literals_in_foreach_calls
                                                                  .forEach(
                                                                      (element) {
                                                                driverData.add(
                                                                    element
                                                                        .value);
                                                              });
                                                              // ignore: avoid_function_literals_in_foreach_calls
                                                              driverData.forEach(
                                                                  (element) {
                                                                if (element['is_active'] ==
                                                                        1 &&
                                                                    element['is_available'] ==
                                                                        true) {
                                                                  if ((choosenTransportType ==
                                                                              0 &&
                                                                          element['transport_type'] ==
                                                                              'taxi') ||
                                                                      choosenTransportType ==
                                                                              0 &&
                                                                          element['transport_type'] ==
                                                                              'both') {
                                                                    DateTime
                                                                        dt =
                                                                        DateTime.fromMillisecondsSinceEpoch(
                                                                            element['updated_at']);

                                                                    if (DateTime.now()
                                                                            .difference(dt)
                                                                            .inMinutes <=
                                                                        2) {
                                                                      if (myMarkers
                                                                          .where((e) => e
                                                                              .markerId
                                                                              .toString()
                                                                              .contains('car#${element['id']}#${element['vehicle_type_icon']}'))
                                                                          .isEmpty) {
                                                                        myMarkers
                                                                            .add(Marker(
                                                                          markerId:
                                                                              MarkerId('car#${element['id']}#${element['vehicle_type_icon']}'),
                                                                          rotation: (myBearings[element['id'].toString()] != null)
                                                                              ? myBearings[element['id'].toString()]
                                                                              : 0.0,
                                                                          position: LatLng(
                                                                              element['l'][0],
                                                                              element['l'][1]),
                                                                          icon: (element['vehicle_type_icon'] == 'taxi')
                                                                              ? pinLocationIcon
                                                                              : bikeIcon,
                                                                        ));
                                                                      } else {
                                                                        if (myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.latitude != element['l'][0] ||
                                                                            myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.longitude !=
                                                                                element['l'][1]) {
                                                                          var dist = calculateDistance(
                                                                              myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.latitude,
                                                                              myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.longitude,
                                                                              element['l'][0],
                                                                              element['l'][1]);
                                                                          if (dist >
                                                                              100) {
                                                                            animationController =
                                                                                AnimationController(
                                                                              duration: const Duration(milliseconds: 1500), //Animation duration of marker

                                                                              vsync: this, //From the widget
                                                                            );

                                                                            animateCar(
                                                                                myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.latitude,
                                                                                myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.longitude,
                                                                                element['l'][0],
                                                                                element['l'][1],
                                                                                _mapMarkerSink,
                                                                                this,
                                                                                // _controller,
                                                                                'car#${element['id']}#${element['vehicle_type_icon']}',
                                                                                element['id'],
                                                                                (element['vehicle_type_icon'] == 'taxi') ? pinLocationIcon : bikeIcon);
                                                                          }
                                                                        }
                                                                      }
                                                                    }
                                                                  } else if ((choosenTransportType ==
                                                                              1 &&
                                                                          element['transport_type'] ==
                                                                              'delivery') ||
                                                                      (choosenTransportType ==
                                                                              1 &&
                                                                          element['transport_type'] ==
                                                                              'both')) {
                                                                    DateTime
                                                                        dt =
                                                                        DateTime.fromMillisecondsSinceEpoch(
                                                                            element['updated_at']);

                                                                    if (DateTime.now()
                                                                            .difference(dt)
                                                                            .inMinutes <=
                                                                        2) {
                                                                      if (myMarkers
                                                                          .where((e) => e
                                                                              .markerId
                                                                              .toString()
                                                                              .contains('car#${element['id']}#${element['vehicle_type_icon']}'))
                                                                          .isEmpty) {
                                                                        myMarkers
                                                                            .add(Marker(
                                                                          markerId:
                                                                              MarkerId('car#${element['id']}#${element['vehicle_type_icon']}'),
                                                                          rotation: (myBearings[element['id'].toString()] != null)
                                                                              ? myBearings[element['id'].toString()]
                                                                              : 0.0,
                                                                          position: LatLng(
                                                                              element['l'][0],
                                                                              element['l'][1]),
                                                                          icon: (element['vehicle_type_icon'] == 'truck')
                                                                              ? deliveryIcon
                                                                              : bikeIcon,
                                                                        ));
                                                                      } else {
                                                                        if (myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.latitude != element['l'][0] ||
                                                                            myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.longitude !=
                                                                                element['l'][1]) {
                                                                          var dist = calculateDistance(
                                                                              myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.latitude,
                                                                              myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.longitude,
                                                                              element['l'][0],
                                                                              element['l'][1]);
                                                                          if (dist >
                                                                              100) {
                                                                            animationController =
                                                                                AnimationController(
                                                                              duration: const Duration(milliseconds: 1500), //Animation duration of marker

                                                                              vsync: this, //From the widget
                                                                            );

                                                                            animateCar(
                                                                              myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.latitude,
                                                                              myMarkers.lastWhere((e) => e.markerId.toString().contains('car#${element['id']}#${element['vehicle_type_icon']}')).position.longitude,
                                                                              element['l'][0],
                                                                              element['l'][1],
                                                                              _mapMarkerSink,
                                                                              this,
                                                                              // _controller,
                                                                              'car#${element['id']}#${element['vehicle_type_icon']}',
                                                                              element['id'],
                                                                              (element['vehicle_type_icon'] == 'truck') ? deliveryIcon : bikeIcon,
                                                                            );
                                                                          }
                                                                        }
                                                                      }
                                                                    }
                                                                  }
                                                                } else {
                                                                  if (myMarkers
                                                                      .where((e) => e
                                                                          .markerId
                                                                          .toString()
                                                                          .contains(
                                                                              'car#${element['id']}#${element['vehicle_type_icon']}'))
                                                                      .isNotEmpty) {
                                                                    myMarkers.removeWhere((e) => e
                                                                        .markerId
                                                                        .toString()
                                                                        .contains(
                                                                            'car#${element['id']}#${element['vehicle_type_icon']}'));
                                                                  }
                                                                }
                                                              });
                                                            }
                                                            if (mapType ==
                                                                'google') {
                                                              return StreamBuilder<
                                                                      List<
                                                                          Marker>>(
                                                                  stream:
                                                                      carMarkerStream,
                                                                  builder: (context,
                                                                      snapshot) {
                                                                    return GoogleMap(
                                                                      onMapCreated:
                                                                          _onMapCreated,
                                                                      compassEnabled:
                                                                          false,
                                                                      initialCameraPosition:
                                                                          CameraPosition(
                                                                        target:
                                                                            center,
                                                                        zoom:
                                                                            14.0,
                                                                      ),
                                                                      onCameraMove:
                                                                          (CameraPosition
                                                                              position) async {
                                                                        if (addressList
                                                                            .isEmpty) {
                                                                        } else {
                                                                          _centerLocation =
                                                                              position.target;
                                                                        }
                                                                      },
                                                                      onCameraIdle:
                                                                          () async {
                                                                        // if (addressList
                                                                        //     .isEmpty) {
                                                                        var val = await geoCoding(
                                                                            _centerLocation.latitude,
                                                                            _centerLocation.longitude);
                                                                        setState(
                                                                            () {
                                                                          if (addressList
                                                                              .where((element) => element.type == 'pickup')
                                                                              .isNotEmpty) {
                                                                            var add = addressList.firstWhere((element) =>
                                                                                element.type ==
                                                                                'pickup');
                                                                            add.address =
                                                                                val;
                                                                            add.latlng =
                                                                                LatLng(_centerLocation.latitude, _centerLocation.longitude);
                                                                          } else {
                                                                            addressList.add(AddressList(
                                                                                id: '1',
                                                                                type: 'pickup',
                                                                                address: val,
                                                                                pickup: true,
                                                                                latlng: LatLng(_centerLocation.latitude, _centerLocation.longitude),
                                                                                name: userDetails['name'],
                                                                                number: userDetails['mobile']));
                                                                          }
                                                                        });
                                                                        _lastCenter =
                                                                            _centerLocation;
                                                                        ischanged =
                                                                            false;
                                                                        setState(
                                                                            () {});
                                                                      },
                                                                      minMaxZoomPreference:
                                                                          const MinMaxZoomPreference(
                                                                              8.0,
                                                                              20.0),
                                                                      myLocationButtonEnabled:
                                                                          false,
                                                                      markers: Set<
                                                                              Marker>.from(
                                                                          myMarkers),
                                                                      buildingsEnabled:
                                                                          false,
                                                                      zoomControlsEnabled:
                                                                          false,
                                                                      myLocationEnabled:
                                                                          true,
                                                                    );
                                                                  });
                                                            }
                                                            return StreamBuilder<
                                                                    List<
                                                                        Marker>>(
                                                                stream:
                                                                    carMarkerStream,
                                                                builder: (context,
                                                                    snapshot) {
                                                                  return fm
                                                                      .FlutterMap(
                                                                    mapController:
                                                                        _fmController,
                                                                    options: fm.MapOptions(
                                                                        onMapEvent: (v) async {
                                                                          if (v.source == fm.MapEventSource.nonRotatedSizeChange &&
                                                                              addressList.isEmpty) {
                                                                            _centerLocation =
                                                                                LatLng(v.camera.center.latitude, v.camera.center.longitude);
                                                                            setState(() {});

                                                                            var val =
                                                                                await geoCoding(_centerLocation.latitude, _centerLocation.longitude);
                                                                            if (val !=
                                                                                '') {
                                                                              setState(() {
                                                                                if (addressList.where((element) => element.type == 'pickup').isNotEmpty) {
                                                                                  var add = addressList.firstWhere((element) => element.type == 'pickup');
                                                                                  add.address = val;
                                                                                  add.latlng = LatLng(_centerLocation.latitude, _centerLocation.longitude);
                                                                                } else {
                                                                                  addressList.add(AddressList(id: '1', type: 'pickup', address: val, pickup: true, latlng: LatLng(_centerLocation.latitude, _centerLocation.longitude), name: userDetails['name'], number: userDetails['mobile']));
                                                                                }
                                                                              });

                                                                              _lastCenter = _centerLocation;
                                                                              ischanged = false;
                                                                            }
                                                                          }
                                                                          if (v.source ==
                                                                              fm.MapEventSource.dragEnd) {
                                                                            _centerLocation =
                                                                                LatLng(v.camera.center.latitude, v.camera.center.longitude);
                                                                            setState(() {});

                                                                            var val =
                                                                                await geoCoding(_centerLocation.latitude, _centerLocation.longitude);
                                                                            if (val !=
                                                                                '') {
                                                                              setState(() {
                                                                                if (addressList.where((element) => element.type == 'pickup').isNotEmpty) {
                                                                                  var add = addressList.firstWhere((element) => element.type == 'pickup');
                                                                                  add.address = val;
                                                                                  add.latlng = LatLng(_centerLocation.latitude, _centerLocation.longitude);
                                                                                } else {
                                                                                  addressList.add(AddressList(id: '1', type: 'pickup', address: val, pickup: true, latlng: LatLng(_centerLocation.latitude, _centerLocation.longitude), name: userDetails['name'], number: userDetails['mobile']));
                                                                                }
                                                                              });

                                                                              _lastCenter = _centerLocation;
                                                                              ischanged = false;
                                                                            }
                                                                          }
                                                                        },
                                                                        onPositionChanged: (p, l) async {
                                                                          if (l ==
                                                                              false) {
                                                                            _centerLocation =
                                                                                LatLng(p.center!.latitude, p.center!.longitude);
                                                                            setState(() {});

                                                                            var val =
                                                                                await geoCoding(_centerLocation.latitude, _centerLocation.longitude);
                                                                            if (val !=
                                                                                '') {
                                                                              setState(() {
                                                                                if (addressList.where((element) => element.type == 'pickup').isNotEmpty) {
                                                                                  var add = addressList.firstWhere((element) => element.type == 'pickup');
                                                                                  add.address = val;
                                                                                  add.latlng = LatLng(_centerLocation.latitude, _centerLocation.longitude);
                                                                                } else {
                                                                                  addressList.add(AddressList(id: '1', type: 'pickup', address: val, pickup: true, latlng: LatLng(_centerLocation.latitude, _centerLocation.longitude), name: userDetails['name'], number: userDetails['mobile']));
                                                                                }
                                                                              });

                                                                              _lastCenter = _centerLocation;
                                                                              ischanged = false;
                                                                            }
                                                                          }
                                                                        },
                                                                        // ignore: deprecated_member_use
                                                                        interactiveFlags: ~fm.InteractiveFlag.doubleTapZoom,
                                                                        initialCenter: fmlt.LatLng(center.latitude, center.longitude),
                                                                        initialZoom: 16,
                                                                        onTap: (P, L) {}),
                                                                    children: [
                                                                      fm.TileLayer(
                                                                        // minZoom: 10,
                                                                        urlTemplate:
                                                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                                        userAgentPackageName:
                                                                            'com.example.app',
                                                                      ),
                                                                      fm.MarkerLayer(
                                                                        markers: myMarkers
                                                                            .asMap()
                                                                            .map((k, value) => MapEntry(
                                                                                k,
                                                                                fm.Marker(
                                                                                    // key: Key('10'),
                                                                                    // rotate: true,
                                                                                    alignment: Alignment.topCenter,
                                                                                    point: fmlt.LatLng(myMarkers[k].position.latitude, myMarkers[k].position.longitude),
                                                                                    width: media.width * 0.7,
                                                                                    height: 50,
                                                                                    child: RotationTransition(
                                                                                        turns: AlwaysStoppedAnimation(myMarkers[k].rotation / 360),
                                                                                        child: Image.asset(
                                                                                          (myMarkers[k].markerId.toString().replaceAll('MarkerId(', '').replaceAll(')', '').split('#')[2].toString() == 'taxi')
                                                                                              ? 'assets/images/top-taxi.png'
                                                                                              : (myMarkers[k].markerId.toString().replaceAll('MarkerId(', '').replaceAll(')', '').split('#')[2].toString() == 'truck')
                                                                                                  ? 'assets/images/deliveryicon.png'
                                                                                                  : 'assets/images/bike.png',
                                                                                        )))))
                                                                            .values
                                                                            .toList(),
                                                                      ),
                                                                      const fm
                                                                          .RichAttributionWidget(
                                                                        attributions: [],
                                                                      ),
                                                                    ],
                                                                  );
                                                                });
                                                          })),
                                                  Positioned(
                                                      top: 0,
                                                      child: Container(
                                                          height:
                                                              media.height * 1,
                                                          width:
                                                              media.width * 1,
                                                          alignment:
                                                              Alignment.center,
                                                          child: (_dropLocationMap ==
                                                                  false)
                                                              ? Column(
                                                                  children: [
                                                                    SizedBox(
                                                                      height: (media.height /
                                                                              2) -
                                                                          media.width *
                                                                              0.08,
                                                                    ),
                                                                    Image.asset(
                                                                      'assets/images/pick_icon.png',
                                                                      width: media
                                                                              .width *
                                                                          0.07,
                                                                      height: media
                                                                              .width *
                                                                          0.08,
                                                                    ),
                                                                  ],
                                                                )
                                                              : Image.asset(
                                                                  'assets/images/dropmarker.png'))),
                                                  Positioned(
                                                    right: 10,
                                                    top: 120,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        if (contactus ==
                                                            false) {
                                                          setState(() {
                                                            contactus = true;
                                                          });
                                                        } else {
                                                          setState(() {
                                                            contactus = false;
                                                          });
                                                        }
                                                      },
                                                      child: Container(
                                                        height:
                                                            media.width * 0.1,
                                                        width:
                                                            media.width * 0.1,
                                                        decoration: BoxDecoration(
                                                            boxShadow: [
                                                              BoxShadow(
                                                                  blurRadius: 2,
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                          0.2),
                                                                  spreadRadius:
                                                                      2)
                                                            ],
                                                            color: page,
                                                            borderRadius: BorderRadius
                                                                .circular(media
                                                                        .width *
                                                                    0.02)),
                                                        alignment:
                                                            Alignment.center,
                                                        child: Image.asset(
                                                            'assets/images/customercare.png',
                                                            fit: BoxFit.contain,
                                                            width: media.width *
                                                                0.06,
                                                            color: textColor),
                                                      ),
                                                    ),
                                                  ),
                                                  (contactus == true)
                                                      ? Positioned(
                                                          right: 10,
                                                          top: 120 +
                                                              media.width * 0.1,
                                                          child: InkWell(
                                                            onTap: () async {},
                                                            child: Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        10),
                                                                height: media
                                                                        .width *
                                                                    0.3,
                                                                width: media
                                                                        .width *
                                                                    0.45,
                                                                decoration: BoxDecoration(
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                          blurRadius:
                                                                              2,
                                                                          color: Colors.black.withOpacity(
                                                                              0.2),
                                                                          spreadRadius:
                                                                              2)
                                                                    ],
                                                                    color: page,
                                                                    borderRadius:
                                                                        BorderRadius.circular(media.width *
                                                                            0.02)),
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceEvenly,
                                                                  children: [
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        makingPhoneCall(
                                                                            userDetails['contact_us_mobile1']);
                                                                      },
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Expanded(
                                                                              flex: 20,
                                                                              child: Icon(
                                                                                Icons.call,
                                                                                color: textColor,
                                                                              )),
                                                                          Expanded(
                                                                              flex: 80,
                                                                              child: Text(
                                                                                userDetails['contact_us_mobile1'],
                                                                                style: GoogleFonts.notoSans(fontSize: media.width * fourteen, color: textColor),
                                                                              ))
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        makingPhoneCall(
                                                                            userDetails['contact_us_mobile1']);
                                                                      },
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Expanded(
                                                                              flex: 20,
                                                                              child: Icon(Icons.call, color: textColor)),
                                                                          Expanded(
                                                                              flex: 80,
                                                                              child: Text(
                                                                                userDetails['contact_us_mobile2'],
                                                                                style: GoogleFonts.notoSans(fontSize: media.width * fourteen, color: textColor),
                                                                              ))
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        openBrowser(
                                                                            userDetails['contact_us_link'].toString());
                                                                      },
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Expanded(
                                                                              flex: 20,
                                                                              child: Icon(Icons.vpn_lock_rounded, color: textColor)),
                                                                          Expanded(
                                                                              flex: 80,
                                                                              child: Text(
                                                                                languages[choosenLanguage]['text_goto_url'],
                                                                                maxLines: 1,
                                                                                style: GoogleFonts.notoSans(fontSize: media.width * fourteen, color: textColor),
                                                                              ))
                                                                        ],
                                                                      ),
                                                                    )
                                                                  ],
                                                                )),
                                                          ),
                                                        )
                                                      : Container(),
                                                  Positioned(
                                                    right: 10,
                                                    top: 155 +
                                                        media.width * 0.35,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        if (locationAllowed ==
                                                            true) {
                                                          if (currentLocation !=
                                                              null) {
                                                            if (mapType ==
                                                                'google') {
                                                              _controller?.animateCamera(
                                                                  CameraUpdate
                                                                      .newLatLngZoom(
                                                                          currentLocation,
                                                                          18.0));
                                                            } else {
                                                              _fmController.move(
                                                                  fmlt.LatLng(
                                                                      currentLocation
                                                                          .latitude,
                                                                      currentLocation
                                                                          .longitude),
                                                                  14);
                                                            }
                                                            center =
                                                                currentLocation;
                                                          } else {
                                                            if (mapType ==
                                                                'google') {
                                                              _controller?.animateCamera(
                                                                  CameraUpdate
                                                                      .newLatLngZoom(
                                                                          center,
                                                                          18.0));
                                                            } else {
                                                              _fmController.move(
                                                                  fmlt.LatLng(
                                                                      center
                                                                          .latitude,
                                                                      center
                                                                          .longitude),
                                                                  14);
                                                            }
                                                          }
                                                        } else {
                                                          if (serviceEnabled ==
                                                              true) {
                                                            setState(() {
                                                              _locationDenied =
                                                                  true;
                                                            });
                                                          } else {
                                                            await geolocs
                                                                    .Geolocator
                                                                .getCurrentPosition(
                                                                    desiredAccuracy:
                                                                        geolocs
                                                                            .LocationAccuracy
                                                                            .low);
                                                            if (await geolocs
                                                                .GeolocatorPlatform
                                                                .instance
                                                                .isLocationServiceEnabled()) {
                                                              setState(() {
                                                                _locationDenied =
                                                                    true;
                                                              });
                                                            }
                                                          }
                                                        }
                                                      },
                                                      child: Container(
                                                        height:
                                                            media.width * 0.1,
                                                        width:
                                                            media.width * 0.1,
                                                        decoration: BoxDecoration(
                                                            boxShadow: [
                                                              BoxShadow(
                                                                  blurRadius: 2,
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                          0.2),
                                                                  spreadRadius:
                                                                      2)
                                                            ],
                                                            color: page,
                                                            borderRadius: BorderRadius
                                                                .circular(media
                                                                        .width *
                                                                    0.02)),
                                                        child: Icon(
                                                            Icons
                                                                .my_location_sharp,
                                                            size: 20,
                                                            color: textColor),
                                                      ),
                                                    ),
                                                  ),
                                                  (userDetails['onTripRequest'] !=
                                                              null &&
                                                          (_lastCenter ==
                                                                  _centerLocation &&
                                                              !ischanged))
                                                      ? Positioned(
                                                          // right: 10,
                                                          bottom: media.width *
                                                              0.68,
                                                          child: InkWell(
                                                            onTap: () async {
                                                              Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              const OnGoingRides()));
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets
                                                                  .all(media
                                                                          .width *
                                                                      0.03),
                                                              height:
                                                                  media.width *
                                                                      0.2,
                                                              width:
                                                                  media.width *
                                                                      1,
                                                              decoration: BoxDecoration(
                                                                  image: const DecorationImage(
                                                                      image: AssetImage(
                                                                          'assets/images/Rectangle.png')),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          media.width *
                                                                              0.02)),
                                                              child: Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: media
                                                                            .width *
                                                                        0.05,
                                                                  ),
                                                                  Column(
                                                                    children: [
                                                                      MyText(
                                                                        text: languages[choosenLanguage]
                                                                            [
                                                                            'text_ongoing_rides'],
                                                                        size: media.width *
                                                                            fourteen,
                                                                        color: Colors
                                                                            .black,
                                                                      ),
                                                                      MyText(
                                                                        text: languages[choosenLanguage]
                                                                            [
                                                                            'text_view_rides'],
                                                                        size: media.width *
                                                                            fourteen,
                                                                        color:
                                                                            verifyDeclined,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Expanded(
                                                                      child:
                                                                          Container(
                                                                    alignment:
                                                                        Alignment
                                                                            .centerLeft,
                                                                    height: media
                                                                            .width *
                                                                        0.07,
                                                                    child:
                                                                        SlideTransition(
                                                                      position:
                                                                          _offsetAnimation,
                                                                      child:
                                                                          SizedBox(
                                                                        child: Image
                                                                            .asset(
                                                                          'assets/images/taxia.png',
                                                                        ),
                                                                      ),
                                                                      // ),
                                                                    ),
                                                                  )),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      : Container(),
                                                  (_bottom == 0)
                                                      ? Positioned(
                                                          top: MediaQuery.of(
                                                                      context)
                                                                  .padding
                                                                  .top +
                                                              20,
                                                          child: SizedBox(
                                                            width: media.width *
                                                                0.9,
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .start,
                                                              children: [
                                                                StatefulBuilder(
                                                                    builder:
                                                                        (context,
                                                                            setState) {
                                                                  return InkWell(
                                                                    onTap: () {
                                                                      Scaffold.of(
                                                                              context)
                                                                          .openDrawer();
                                                                    },
                                                                    child: Container(
                                                                        height: media.width * 0.1,
                                                                        width: media.width * 0.1,
                                                                        decoration: BoxDecoration(boxShadow: [
                                                                          (_bottom == 0)
                                                                              ? BoxShadow(blurRadius: (_bottom == 0) ? 2 : 0, color: (_bottom == 0) ? Colors.black.withOpacity(0.2) : Colors.transparent, spreadRadius: (_bottom == 0) ? 2 : 0)
                                                                              : const BoxShadow(),
                                                                        ], color: page, borderRadius: BorderRadius.circular(4)),
                                                                        alignment: Alignment.center,
                                                                        child: Icon(Icons.menu, size: media.width * 0.05, color: textColor)),
                                                                  );
                                                                }),
                                                                SizedBox(
                                                                  width: media
                                                                          .width *
                                                                      0.02,
                                                                ),
                                                                (banners
                                                                        .isNotEmpty)
                                                                    ? SizedBox(
                                                                        width: media.width *
                                                                            0.77,
                                                                        height: media.width *
                                                                            0.15,
                                                                        child: (banners.length ==
                                                                                1)
                                                                            ? ClipRRect(
                                                                                borderRadius: BorderRadius.circular(20),
                                                                                child: Image.network(
                                                                                  banners[0]['image'],
                                                                                  fit: BoxFit.fitWidth,
                                                                                ))
                                                                            : const BannerImage())
                                                                    : Container(),
                                                              ],
                                                            ),
                                                          ))
                                                      : Container(),
                                                  Positioned(
                                                      bottom: 0,
                                                      child: GestureDetector(
                                                        onVerticalDragStart:
                                                            (d) {
                                                          gesture.clear();
                                                          start = d
                                                              .globalPosition
                                                              .dy;

                                                          if (start > 50) {
                                                            _bottom = 0;
                                                            if (choosenTransportType ==
                                                                2) {
                                                              
                                                              choosenTransportType =
                                                                  0;
                                                            }
                                                          } else {
                                                            _bottom = 1;
                                                          }
                                                        },
                                                        onVerticalDragUpdate:
                                                            (d) {
                                                          gesture.add(d
                                                              .globalPosition
                                                              .dy);
                                                          _height = media
                                                                  .height -
                                                              d.globalPosition
                                                                  .dy;
                                                          setState(() {
                                                            if (choosenTransportType !=
                                                                2) {
                                                              
                                                            }
                                                          });
                                                        },
                                                        onVerticalDragEnd: (d) {
                                                          if (gesture
                                                                  .isNotEmpty &&
                                                              start <
                                                                  gesture[gesture
                                                                          .length -
                                                                      1]) {
                                                            setState(() {
                                                              _height =
                                                                  media.width *
                                                                      0.68;
                                                              _bottom = 0;
                                                              if (choosenTransportType ==
                                                                  2) {
                                                               
                                                                choosenTransportType =
                                                                    0;
                                                              }
                                                              addAutoFill
                                                                  .clear();
                                                              _pickaddress =
                                                                  false;
                                                              _dropaddress =
                                                                  false;
                                                            });
                                                          } else {
                                                            _height =
                                                                media.height *
                                                                    1;
                                                            Future.delayed(
                                                                const Duration(
                                                                    milliseconds:
                                                                        200),
                                                                () {
                                                              setState(() {
                                                                _bottom = 1;
                                                                _dropaddress =
                                                                    true;
                                                              });
                                                            });
                                                            setState(() {});
                                                          }
                                                        },
                                                        child:
                                                            AnimatedContainer(
                                                          padding: EdgeInsets
                                                              .fromLTRB(
                                                                  media.width *
                                                                      0.025,
                                                                  media.width *
                                                                      0.015,
                                                                  media.width *
                                                                      0.025,
                                                                  0),
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      500),
                                                          width:
                                                              media.width * 1,
                                                          height: _height == 0
                                                              ? media.width *
                                                                  0.5
                                                              : _height,
                                                          constraints: BoxConstraints(
                                                              minHeight:
                                                                  media.width *
                                                                      0.68,
                                                              maxHeight:
                                                                  media.height *
                                                                      1),
                                                          curve: Curves
                                                              .fastOutSlowIn,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: page,
                                                            borderRadius: (_bottom ==
                                                                    0)
                                                                ? const BorderRadius
                                                                    .only(
                                                                    topLeft: Radius
                                                                        .circular(
                                                                            10),
                                                                    topRight: Radius
                                                                        .circular(
                                                                            10))
                                                                : BorderRadius
                                                                    .circular(
                                                                        0),
                                                          ),
                                                          child: Column(
                                                            children: [
                                                              (_bottom == 1)
                                                                  ? Column(
                                                                      children: [
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.08,
                                                                        ),
                                                                        Row(
                                                                          children: [
                                                                            InkWell(
                                                                              onTap: () {
                                                                                setState(() {
                                                                                  _height = media.width * 0.68;
                                                                                  _bottom = 0;
                                                                                  if (choosenTransportType == 2) {
                                                                                    choosenTransportType = 0;
                                                                                  }
                                                                                  addAutoFill.clear();
                                                                                  _pickaddress = false;
                                                                                  _dropaddress = false;
                                                                                });
                                                                              },
                                                                              child: Icon(Icons.arrow_back_ios, color: textColor),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    )
                                                                  : Container(),
                                                              (_bottom == 1)
                                                                  ? Container(
                                                                      height: media
                                                                              .width *
                                                                          0.33,
                                                                      width: media
                                                                              .width *
                                                                          0.9,
                                                                      padding: EdgeInsets.all(
                                                                          media.width *
                                                                              0.02),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(media.width *
                                                                                0.02),
                                                                        color:
                                                                            page,
                                                                      ),
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          SizedBox(
                                                                            height:
                                                                                media.width * 0.02,
                                                                          ),
                                                                          (_pickaddress == true && _bottom == 1)
                                                                              ? SizedBox(
                                                                                  height: media.width * 0.08,
                                                                                  width: media.width * 0.9,
                                                                                  child: Row(
                                                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                                                    children: [
                                                                                      Container(
                                                                                        height: media.width * 0.05,
                                                                                        width: media.width * 0.05,
                                                                                        alignment: Alignment.center,
                                                                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                                                                                        child: Container(
                                                                                          height: media.width * 0.02,
                                                                                          width: media.width * 0.02,
                                                                                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.6)),
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(
                                                                                        width: media.width * 0.02,
                                                                                      ),
                                                                                      Expanded(
                                                                                        child: TextField(
                                                                                            autofocus: (_pickaddress) ? true : false,
                                                                                            minLines: 1,
                                                                                            decoration: InputDecoration(
                                                                                              contentPadding: (languageDirection == 'rtl') ? EdgeInsets.only(bottom: media.width * 0.035) : EdgeInsets.only(bottom: media.width * 0.03),
                                                                                              border: InputBorder.none,
                                                                                              hintText: languages[choosenLanguage]['text_4letterpickup'],
                                                                                              hintStyle: GoogleFonts.notoSans(
                                                                                                fontSize: media.width * twelve,
                                                                                                color: textColor.withOpacity(0.4),
                                                                                              ),
                                                                                            ),
                                                                                            style: GoogleFonts.notoSans(fontSize: media.width * fourteen, color: (isDarkTheme == true) ? Colors.white : textColor),
                                                                                            maxLines: 1,
                                                                                            onChanged: (val) {
                                                                                              _debouncer.run(() {
                                                                                                if (val.length >= 4) {
                                                                                                  if (storedAutoAddress.where((element) => element['description'].toString().toLowerCase().contains(val.toLowerCase()) || element['display_name'].toString().toLowerCase().contains(val.toLowerCase())).isNotEmpty) {
                                                                                                    addAutoFill.removeWhere((element) => element['description'].toString().toLowerCase().contains(val.toLowerCase()) == false || element['display_name'].toString().toLowerCase().contains(val.toLowerCase()) == false);
                                                                                                    storedAutoAddress.where((element) => element['description'].toString().toLowerCase().contains(val.toLowerCase()) || element['display_name'].toString().toLowerCase().contains(val.toLowerCase())).forEach((element) {
                                                                                                      addAutoFill.add(element);
                                                                                                    });
                                                                                                    valueNotifierHome.incrementNotifier();
                                                                                                  } else {
                                                                                                    getAutocomplete(val, _sessionToken, center.latitude, center.longitude);
                                                                                                  }
                                                                                                } else {
                                                                                                  setState(() {
                                                                                                    addAutoFill.clear();
                                                                                                  });
                                                                                                }
                                                                                              });
                                                                                            }),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                )
                                                                              : SizedBox(
                                                                                  height: media.width * 0.08,
                                                                                  child: Row(
                                                                                    children: [
                                                                                      Container(
                                                                                        height: media.width * 0.05,
                                                                                        width: media.width * 0.05,
                                                                                        alignment: Alignment.center,
                                                                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                                                                                        child: Container(
                                                                                          height: media.width * 0.02,
                                                                                          width: media.width * 0.02,
                                                                                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.6)),
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(width: media.width * 0.02),
                                                                                      Expanded(
                                                                                        child: InkWell(
                                                                                          onTap: () {
                                                                                            setState(() {
                                                                                              _dropaddress = false;
                                                                                              _pickaddress = true;
                                                                                            });
                                                                                          },
                                                                                          child: Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            children: [
                                                                                              SizedBox(
                                                                                                width: media.width * 0.55,
                                                                                                child: MyText(
                                                                                                  text: (addressList.where((element) => element.type == 'pickup').isNotEmpty) ? addressList.firstWhere((element) => element.type == 'pickup', orElse: () => AddressList(id: '', address: '', pickup: true, latlng: const LatLng(0.0, 0.0))).address : languages[choosenLanguage]['text_4letterpickup'],
                                                                                                  size: media.width * fourteen,
                                                                                                  color: textColor,
                                                                                                  maxLines: 1,
                                                                                                  overflow: TextOverflow.ellipsis,
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                          SizedBox(
                                                                            height:
                                                                                media.width * 0.03,
                                                                          ),
                                                                          (_bottom == 0)
                                                                              ? SizedBox(
                                                                                  height: media.width * 0.06,
                                                                                  child: Row(
                                                                                    children: [
                                                                                      Container(
                                                                                        height: media.width * 0.05,
                                                                                        width: media.width * 0.05,
                                                                                        alignment: Alignment.center,
                                                                                        decoration: BoxDecoration(shape: BoxShape.circle, color: (isDarkTheme == true) ? Colors.white : const Color(0xffFF0000).withOpacity(0.3)),
                                                                                        child: Icon(
                                                                                          Icons.place,
                                                                                          size: media.width * 0.04,
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(width: media.width * 0.02),
                                                                                      Expanded(
                                                                                        child: InkWell(
                                                                                          onTap: () {
                                                                                            setState(() {
                                                                                              _pickaddress = false;
                                                                                              _dropaddress = true;
                                                                                            });
                                                                                          },
                                                                                          child: Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            children: [
                                                                                              SizedBox(
                                                                                                width: media.width * 0.55,
                                                                                                child: MyText(
                                                                                                  text: languages[choosenLanguage]['text_4lettersforautofill'],
                                                                                                  size: media.width * fourteen,
                                                                                                  color: (isDarkTheme == true) ? Colors.white : textColor,
                                                                                                  maxLines: 1,
                                                                                                  overflow: TextOverflow.ellipsis,
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      )
                                                                                    ],
                                                                                  ),
                                                                                )
                                                                              : Container(),
                                                                          (_bottom == 1 && _dropaddress)
                                                                              ? SizedBox(
                                                                                  height: media.width * 0.08,
                                                                                  width: media.width * 0.9,
                                                                                  child: Row(
                                                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                                                    children: [
                                                                                      Container(
                                                                                        height: media.width * 0.05,
                                                                                        width: media.width * 0.05,
                                                                                        alignment: Alignment.center,
                                                                                        decoration: BoxDecoration(shape: BoxShape.circle, color: (isDarkTheme == true) ? Colors.white : const Color(0xffFF0000).withOpacity(0.3)),
                                                                                        child: Icon(
                                                                                          Icons.place,
                                                                                          size: media.width * 0.04,
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(
                                                                                        width: media.width * 0.02,
                                                                                      ),
                                                                                      Expanded(
                                                                                        child: TextField(
                                                                                            autofocus: (_dropaddress) ? true : false,
                                                                                            minLines: 1,
                                                                                            decoration: InputDecoration(
                                                                                              contentPadding: (languageDirection == 'rtl') ? EdgeInsets.only(bottom: media.width * 0.035) : EdgeInsets.only(bottom: media.width * 0.03),
                                                                                              border: InputBorder.none,
                                                                                              hintText: languages[choosenLanguage]['text_4lettersforautofill'],
                                                                                              hintStyle: GoogleFonts.notoSans(
                                                                                                fontSize: media.width * twelve,
                                                                                                color: textColor.withOpacity(0.4),
                                                                                              ),
                                                                                            ),
                                                                                            style: GoogleFonts.notoSans(fontSize: media.width * fourteen, color: (isDarkTheme == true) ? Colors.white : textColor),
                                                                                            maxLines: 1,
                                                                                            onChanged: (val) {
                                                                                              _debouncer.run(() {
                                                                                                if (val.length >= 4) {
                                                                                                  getAutocomplete(val, _sessionToken, center.latitude, center.longitude);
                                                                                                } else {
                                                                                                  setState(() {
                                                                                                    addAutoFill.clear();
                                                                                                  });
                                                                                                }
                                                                                              });
                                                                                            }),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                )
                                                                              : SizedBox(
                                                                                  height: media.width * 0.08,
                                                                                  child: Row(
                                                                                    children: [
                                                                                      Container(
                                                                                        height: media.width * 0.05,
                                                                                        width: media.width * 0.05,
                                                                                        alignment: Alignment.center,
                                                                                        decoration: BoxDecoration(shape: BoxShape.circle, color: (isDarkTheme == true) ? Colors.white : const Color(0xffFF0000).withOpacity(0.3)),
                                                                                        child: Icon(
                                                                                          Icons.place,
                                                                                          size: media.width * 0.04,
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(width: media.width * 0.02),
                                                                                      Expanded(
                                                                                        child: InkWell(
                                                                                          onTap: () {
                                                                                            setState(() {
                                                                                              _dropaddress = true;
                                                                                              _pickaddress = false;
                                                                                            });
                                                                                          },
                                                                                          child: Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            children: [
                                                                                              SizedBox(
                                                                                                width: media.width * 0.55,
                                                                                                child: MyText(
                                                                                                  text: languages[choosenLanguage]['text_4lettersforautofill'],
                                                                                                  size: media.width * twelve,
                                                                                                  color: hintColor,
                                                                                                  maxLines: 1,
                                                                                                  overflow: TextOverflow.ellipsis,
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : Container(),
                                                              (_bottom == 1)
                                                                  ? InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        setState(
                                                                            () {
                                                                          addAutoFill
                                                                              .clear();
                                                                          _height =
                                                                              media.width * 0.68;
                                                                          _bottom =
                                                                              0;
                                                                        });
                                                                        if (_dropaddress ==
                                                                                true &&
                                                                            addressList.where((element) => element.type == 'pickup').isNotEmpty) {
                                                                          var navigate = await Navigator.push(
                                                                              context,
                                                                              MaterialPageRoute(builder: (context) => DropLocation()));
                                                                          if (navigate !=
                                                                              null) {
                                                                            if (navigate) {
                                                                              setState(() {
                                                                                addressList.removeWhere((element) => element.type == 'drop');
                                                                              });
                                                                            }
                                                                          }
                                                                        } else {}
                                                                      },
                                                                      child:
                                                                          Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          Image
                                                                              .asset(
                                                                            (_dropaddress)
                                                                                ? 'assets/images/dropmarker.png'
                                                                                : 'assets/images/pickupmarker.png',
                                                                            width:
                                                                                media.width * 0.05,
                                                                            height:
                                                                                media.width * 0.05,
                                                                          ),
                                                                          MyText(
                                                                            text:
                                                                                languages[choosenLanguage]['text_view_on_map'],
                                                                            size:
                                                                                media.width * sixteen,
                                                                            color:
                                                                                textColor.withOpacity(0.4),
                                                                          ),
                                                                        ],
                                                                      ))
                                                                  : Container(),
                                                              SizedBox(
                                                                height: media
                                                                        .width *
                                                                    0.03,
                                                              ),
                                                              (_bottom == 1 &&
                                                                      userDetails['show_ride_without_destination']
                                                                              .toString() ==
                                                                          '1' &&
                                                                      choosenTransportType ==
                                                                          0)
                                                                  ? Column(
                                                                      children: [
                                                                        Container(
                                                                          width:
                                                                              media.width * 0.9,
                                                                          height:
                                                                              media.width * 0.1,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            borderRadius:
                                                                                BorderRadius.circular(media.width * 0.02),
                                                                            color:
                                                                                topBar,
                                                                          ),
                                                                          child:
                                                                              Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                              InkWell(
                                                                                onTap: () {
                                                                                  ismulitipleride = false;

                                                                                  // if (_dropaddress == true) {
                                                                                  setState(() {
                                                                                    Navigator.pushAndRemoveUntil(
                                                                                        context,
                                                                                        MaterialPageRoute(
                                                                                            builder: (context) => BookingConfirmation(
                                                                                                  type: 2,
                                                                                                )),
                                                                                        (route) => false);
                                                                                  });

                                                                                  // }
                                                                                },
                                                                                child: Row(
                                                                                  children: [
                                                                                    Container(
                                                                                      padding: EdgeInsets.all(media.width * 0.01),
                                                                                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(media.width * 0.01)),
                                                                                      child: RotatedBox(
                                                                                        quarterTurns: 3,
                                                                                        child: Icon(
                                                                                          Icons.route_sharp,
                                                                                          color: (isDarkTheme == true) ? Colors.black : textColor,
                                                                                          size: media.width * sixteen,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    SizedBox(
                                                                                      width: media.width * 0.02,
                                                                                    ),
                                                                                    MyText(text: languages[choosenLanguage]['text_ridewithout_destination'], size: media.width * sixteen, fontweight: FontWeight.w600, color: (isDarkTheme == true) ? Colors.black : buttonColor),
                                                                                  ],
                                                                                ),
                                                                              )
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    )
                                                                  : Container(),
                                                              (favAddress.isNotEmpty &&
                                                                      _bottom ==
                                                                          1 &&
                                                                      addAutoFill
                                                                          .isEmpty)
                                                                  ? Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.03,
                                                                        ),
                                                                        MyText(
                                                                          text: languages[choosenLanguage]
                                                                              [
                                                                              'text_saved_place'],
                                                                          size: media.width *
                                                                              fourteen,
                                                                          fontweight:
                                                                              FontWeight.w700,
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.02,
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              media.width * 0.9,
                                                                          child:
                                                                              SingleChildScrollView(
                                                                            child:
                                                                                Column(
                                                                              children: [
                                                                                (favAddress.isNotEmpty)
                                                                                    ? Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: favAddress
                                                                                            .asMap()
                                                                                            .map((i, value) {
                                                                                              return MapEntry(
                                                                                                  i,
                                                                                                  (i < 5)
                                                                                                      ? Container(
                                                                                                          padding: EdgeInsets.fromLTRB(0, media.width * 0.04, 0, media.width * 0.04),
                                                                                                          decoration: BoxDecoration(
                                                                                                            border: Border(bottom: BorderSide(width: 1.0, color: (isDarkTheme == true) ? textColor.withOpacity(0.2) : textColor.withOpacity(0.1))),
                                                                                                          ),
                                                                                                          child: Column(
                                                                                                            children: [
                                                                                                              SizedBox(
                                                                                                                width: media.width * 0.9,
                                                                                                                child: MyText(text: favAddress[i]['address_name'], size: media.width * twelve, maxLines: 2),
                                                                                                              ),
                                                                                                              SizedBox(
                                                                                                                height: media.width * 0.025,
                                                                                                              ),
                                                                                                              Row(
                                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                                children: [
                                                                                                                  SizedBox(
                                                                                                                    height: media.width * 0.05,
                                                                                                                    width: media.width * 0.05,
                                                                                                                    child: (favAddress[i]['address_name'] == 'Home')
                                                                                                                        ? Image.asset(
                                                                                                                            'assets/images/home.png',
                                                                                                                            color: textColor,
                                                                                                                            width: media.width * 0.04,
                                                                                                                          )
                                                                                                                        : (favAddress[i]['address_name'] == 'Work')
                                                                                                                            ? Image.asset(
                                                                                                                                'assets/images/briefcase.png',
                                                                                                                                color: textColor,
                                                                                                                                width: media.width * 0.04,
                                                                                                                              )
                                                                                                                            : Image.asset(
                                                                                                                                'assets/images/navigation.png',
                                                                                                                                color: textColor,
                                                                                                                                width: media.width * 0.04,
                                                                                                                              ),
                                                                                                                  ),
                                                                                                                  InkWell(
                                                                                                                    onTap: () async {
                                                                                                                      if (_pickaddress == true) {
                                                                                                                        setState(() {
                                                                                                                          addAutoFill.clear();
                                                                                                                          if (addressList.where((element) => element.type == 'pickup').isEmpty) {
                                                                                                                            addressList.add(AddressList(id: '1', type: 'pickup', pickup: true, address: favAddress[i]['pick_address'], latlng: LatLng(favAddress[i]['pick_lat'], favAddress[i]['pick_lng'])));
                                                                                                                          } else {
                                                                                                                            addressList.firstWhere((element) => element.type == 'pickup').address = favAddress[i]['pick_address'];
                                                                                                                            addressList.firstWhere((element) => element.type == 'pickup').latlng = LatLng(favAddress[i]['pick_lat'], favAddress[i]['pick_lng']);
                                                                                                                          }
                                                                                                                          _controller?.moveCamera(CameraUpdate.newLatLngZoom(LatLng(favAddress[i]['pick_lat'], favAddress[i]['pick_lng']), 14.0));
                                                                                                                          _height = media.width * 0.68;
                                                                                                                          _bottom = 0;
                                                                                                                          if (choosenTransportType == 2) {
                                                                                                                            choosenTransportType = 0;
                                                                                                                          }
                                                                                                                        });
                                                                                                                      } else {
                                                                                                                        setState(() {
                                                                                                                          if (addressList.where((element) => element.type == 'drop').isEmpty) {
                                                                                                                            addressList.add(AddressList(id: '2', type: 'drop', address: favAddress[i]['pick_address'], pickup: false, latlng: LatLng(favAddress[i]['pick_lat'], favAddress[i]['pick_lng'])));
                                                                                                                          } else {
                                                                                                                            addressList.firstWhere((element) => element.type == 'drop').address = favAddress[i]['pick_address'];
                                                                                                                            addressList.firstWhere((element) => element.type == 'drop').latlng = LatLng(favAddress[i]['pick_lat'], favAddress[i]['pick_lng']);
                                                                                                                          }
                                                                                                                          addAutoFill.clear();
                                                                                                                          _height = media.width * 0.68;
                                                                                                                          _bottom = 0;
                                                                                                                          if (choosenTransportType == 2) {
                                                                                                                            choosenTransportType = 0;
                                                                                                                          }
                                                                                                                        });
                                                                                                                        if (addressList.length == 2) {
                                                                                                                          if (choosenTransportType == 0) {
                                                                                                                            ismulitipleride = false;

                                                                                                                            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => BookingConfirmation()), (route) => false);
                                                                                                                          } else {
                                                                                                                            Navigator.push(context, MaterialPageRoute(builder: (context) => DropLocation()));
                                                                                                                          }

                                                                                                                          dropAddress = favAddress[i]['pick_address'];
                                                                                                                        }
                                                                                                                      }
                                                                                                                    },
                                                                                                                    child: SizedBox(
                                                                                                                      width: media.width * 0.8,
                                                                                                                      child: MyText(text: favAddress[i]['pick_address'], size: media.width * twelve, maxLines: 2),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                ],
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                        )
                                                                                                      : Container());
                                                                                            })
                                                                                            .values
                                                                                            .toList(),
                                                                                      )
                                                                                    : Container(),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    )
                                                                  : Container(),
                                                              (_bottom == 0)
                                                                  ? SizedBox(
                                                                      width: media
                                                                              .width *
                                                                          0.9,
                                                                      child:
                                                                          SingleChildScrollView(
                                                                        scrollDirection:
                                                                            Axis.horizontal,
                                                                        physics:
                                                                            const BouncingScrollPhysics(),
                                                                        child:
                                                                            Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            (userDetails['enable_modules_for_applications'] == 'both' || userDetails['enable_modules_for_applications'] == 'taxi')
                                                                                ? Row(
                                                                                    children: [
                                                                                      Column(
                                                                                        children: [
                                                                                          Material(
                                                                                            elevation: 10,
                                                                                            borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                            child: InkWell(
                                                                                              onTap: () {
                                                                                                if (choosenTransportType != 0) {
                                                                                                  setState(() {
                                                                                                    choosenTransportType = 0;
                                                                                                    myMarkers.clear();
                                                                                                  });
                                                                                                }
                                                                                              },
                                                                                              child: Container(
                                                                                                padding: EdgeInsets.all(media.width * 0.01),
                                                                                                width: media.width * 0.2,
                                                                                                height: media.width * 0.17,
                                                                                                decoration: BoxDecoration(
                                                                                                  color: (choosenTransportType == 0)
                                                                                                      ? (isDarkTheme)
                                                                                                          ? Colors.green
                                                                                                          : Colors.green[200]
                                                                                                      : page,
                                                                                                  borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                                  border: Border.all(color: (choosenTransportType == 0) ? buttonColor : Colors.transparent, width: 2),
                                                                                                  // color: ,
                                                                                                ),
                                                                                                child: Column(
                                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                  children: [
                                                                                                    Image.asset(
                                                                                                      'assets/images/taxiride.png',
                                                                                                      height: media.width * 0.06,
                                                                                                    ),
                                                                                                    SizedBox(
                                                                                                      height: media.width * 0.01,
                                                                                                    ),
                                                                                                    MyText(
                                                                                                      text: languages[choosenLanguage]['text_taxi_'],
                                                                                                      size: media.width * fourteen,
                                                                                                      fontweight: FontWeight.w500,
                                                                                                    )
                                                                                                  ],
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                      SizedBox(
                                                                                        width: media.width * 0.02,
                                                                                      )
                                                                                    ],
                                                                                  )
                                                                                : Container(),
                                                                            (userDetails['enable_modules_for_applications'] == 'both' || userDetails['enable_modules_for_applications'] == 'delivery')
                                                                                ? Row(
                                                                                    children: [
                                                                                      Column(
                                                                                        children: [
                                                                                          Material(
                                                                                            elevation: 10,
                                                                                            borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                            child: InkWell(
                                                                                              onTap: () {
                                                                                                if (choosenTransportType != 1) {
                                                                                                  setState(() {
                                                                                                    choosenTransportType = 1;
                                                                                                    myMarkers.clear();
                                                                                                  });
                                                                                                }
                                                                                              },
                                                                                              child: Container(
                                                                                                padding: EdgeInsets.all(media.width * 0.01),
                                                                                                width: media.width * 0.2,
                                                                                                height: media.width * 0.17,
                                                                                                decoration: BoxDecoration(
                                                                                                  color: (choosenTransportType == 1)
                                                                                                      ? (isDarkTheme)
                                                                                                          ? Colors.green
                                                                                                          : Colors.green[200]
                                                                                                      : page,
                                                                                                  borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                                  border: Border.all(color: (choosenTransportType == 1) ? buttonColor : Colors.transparent, width: 2),
                                                                                                  // color: ,
                                                                                                ),
                                                                                                child: Column(
                                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                  children: [
                                                                                                    // Icon(Icons.luggage_outlined)
                                                                                                    Image.asset(
                                                                                                      'assets/images/deliveryride.png',
                                                                                                      height: media.width * 0.06,
                                                                                                    ),
                                                                                                    SizedBox(
                                                                                                      height: media.width * 0.01,
                                                                                                    ),
                                                                                                    MyText(
                                                                                                      text: languages[choosenLanguage]['text_delivery'],
                                                                                                      size: media.width * fourteen,
                                                                                                      fontweight: FontWeight.w500,
                                                                                                    )
                                                                                                  ],
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                      SizedBox(
                                                                                        width: media.width * 0.02,
                                                                                      )
                                                                                    ],
                                                                                  )
                                                                                : Container(),
                                                                            (userDetails['show_rental_ride'] == true)
                                                                                ? Row(
                                                                                    children: [
                                                                                      Column(
                                                                                        children: [
                                                                                          InkWell(
                                                                                            onTap: () {
                                                                                              addressList.removeWhere((element) => element.type == 'drop');

                                                                                              if (userDetails['enable_modules_for_applications'] == 'taxi') {
                                                                                                choosenTransportType = 0;
                                                                                                ismulitipleride = false;
                                                                                                Navigator.pushAndRemoveUntil(
                                                                                                    context,
                                                                                                    MaterialPageRoute(
                                                                                                        builder: (context) => BookingConfirmation(
                                                                                                              type: 1,
                                                                                                            )),
                                                                                                    (route) => false);
                                                                                              } else if (userDetails['enable_modules_for_applications'] == 'delivery') {
                                                                                                choosenTransportType = 1;
                                                                                                ismulitipleride = false;
                                                                                                Navigator.pushAndRemoveUntil(
                                                                                                    context,
                                                                                                    MaterialPageRoute(
                                                                                                        builder: (context) => BookingConfirmation(
                                                                                                              type: 1,
                                                                                                            )),
                                                                                                    (route) => false);
                                                                                              } else {
                                                                                                if (choosenTransportType != 3) {
                                                                                                  setState(() {
                                                                                                    choosenTransportType = 3;
                                                                                                    _isbottom = 0;
                                                                                                    _outstationheight = media.height * 0.25;
                                                                                                    myMarkers.clear();
                                                                                                  });
                                                                                                }
                                                                                              }
                                                                                            },
                                                                                            child: Material(
                                                                                              elevation: 10,
                                                                                              borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                              child: Container(
                                                                                                padding: EdgeInsets.all(media.width * 0.01),
                                                                                                width: media.width * 0.2,
                                                                                                height: media.width * 0.17,
                                                                                                decoration: BoxDecoration(
                                                                                                  color: (choosenTransportType == 3)
                                                                                                      ? (isDarkTheme)
                                                                                                          ? Colors.green
                                                                                                          : Colors.green[200]
                                                                                                      : page,
                                                                                                  borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                                  border: Border.all(color: (choosenTransportType == 3) ? buttonColor : Colors.transparent, width: 2),
                                                                                                  // color: ,
                                                                                                ),
                                                                                                child: Column(
                                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                  children: [
                                                                                                    Icon(
                                                                                                      Icons.alarm_outlined,
                                                                                                      color: textColor,
                                                                                                      size: media.width * 0.07,
                                                                                                    ),
                                                                                                    SizedBox(
                                                                                                      height: media.width * 0.01,
                                                                                                    ),
                                                                                                    MyText(
                                                                                                      text: languages[choosenLanguage]['text_rental'],
                                                                                                      size: media.width * fourteen,
                                                                                                      fontweight: FontWeight.w500,
                                                                                                    )
                                                                                                  ],
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    
                                                                                    ],
                                                                                  )
                                                                                : Container(),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : Container(),
                                                              SizedBox(
                                                                height: media
                                                                        .width *
                                                                    0.03,
                                                              ),
                                                              (_bottom == 0)
                                                                  ? Column(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        InkWell(
                                                                          onTap:
                                                                              () {
                                                                            if (addressList.where((element) => element.type == 'pickup').isNotEmpty) {
                                                                              setState(() {
                                                                                _pickaddress = true;
                                                                                _dropaddress = false;
                                                                                addAutoFill.clear();
                                                                                _height = media.height * 1;
                                                                              });

                                                                              Future.delayed(const Duration(milliseconds: 200), () {
                                                                                setState(() {
                                                                                  _bottom = 1;
                                                                                });
                                                                              });
                                                                            }
                                                                          },
                                                                          child:
                                                                              Container(
                                                                            padding:
                                                                                EdgeInsets.all(media.width * 0.01),
                                                                            decoration: BoxDecoration(
                                                                                color: page,
                                                                                borderRadius: BorderRadius.circular(media.width * 0.01),
                                                                                border: Border.all(color: hintColor)),
                                                                            height:
                                                                                media.width * 0.1,
                                                                            width:
                                                                                media.width * 0.9,
                                                                            child:
                                                                                Row(
                                                                              children: [
                                                                                Container(
                                                                                  height: media.width * 0.05,
                                                                                  width: media.width * 0.05,
                                                                                  alignment: Alignment.center,
                                                                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                                                                                  child: Container(
                                                                                    height: media.width * 0.02,
                                                                                    width: media.width * 0.02,
                                                                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.6)),
                                                                                  ),
                                                                                ),
                                                                                SizedBox(width: media.width * 0.02),
                                                                                Expanded(
                                                                                  child: MyText(
                                                                                    text: (addressList.where((element) => element.type == 'pickup').isNotEmpty) ? addressList.firstWhere((element) => element.type == 'pickup', orElse: () => AddressList(id: '', address: '', pickup: true, latlng: const LatLng(0.0, 0.0))).address : languages[choosenLanguage]['text_4letterpickup'],
                                                                                    size: media.width * fourteen,
                                                                                    color: textColor,
                                                                                    maxLines: 1,
                                                                                    overflow: TextOverflow.ellipsis,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.04,
                                                                        ),
                                                                        Stack(
                                                                          children: [
                                                                            Container(
                                                                              padding: EdgeInsets.all(media.width * 0.01),
                                                                              decoration: BoxDecoration(color: hintColor.withOpacity(0.1), borderRadius: BorderRadius.circular(media.width * 0.01), border: Border.all(color: hintColor)),
                                                                              height: media.width * 0.1,
                                                                              width: media.width * 0.9,
                                                                              child: Row(
                                                                                children: [
                                                                                  Container(
                                                                                    height: media.width * 0.06,
                                                                                    width: media.width * 0.06,
                                                                                    alignment: Alignment.center,
                                                                                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xffFF0000).withOpacity(0.3)),
                                                                                    child: Container(
                                                                                      height: media.width * 0.06,
                                                                                      width: media.width * 0.06,
                                                                                      alignment: Alignment.center,
                                                                                      child: Icon(
                                                                                        Icons.location_on_outlined,
                                                                                        color: verifyDeclined,
                                                                                        size: media.width * 0.05,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  SizedBox(width: media.width * 0.02),
                                                                                  SizedBox(
                                                                                    width: media.width * 0.7,
                                                                                    child: AnimatedTextKit(
                                                                                      repeatForever: true,
                                                                                      animatedTexts: [
                                                                                        TyperAnimatedText(languages[choosenLanguage]['text_4lettersforautofill'],
                                                                                            textStyle: GoogleFonts.notoSans(
                                                                                              fontSize: media.width * fourteen,
                                                                                              color: hintColor,
                                                                                              fontWeight: FontWeight.w700,
                                                                                            ))
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                            Positioned(
                                                                                child: InkWell(
                                                                              onTap: () {
                                                                                if (addressList.where((element) => element.type == 'pickup').isNotEmpty) {
                                                                                  setState(() {
                                                                                    _pickaddress = false;
                                                                                    _dropaddress = true;
                                                                                    addAutoFill.clear();
                                                                                    _height = media.height * 1;
                                                                                  });

                                                                                  Future.delayed(const Duration(milliseconds: 200), () {
                                                                                    setState(() {
                                                                                      _bottom = 1;
                                                                                    });
                                                                                  });
                                                                                }
                                                                              },
                                                                              child: Container(
                                                                                height: media.width * 0.1,
                                                                                width: media.width * 0.9,
                                                                                color: Colors.transparent,
                                                                              ),
                                                                            ))
                                                                          ],
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.03,
                                                                        ),
                                                                        (userDetails['show_ride_without_destination'].toString() == '1' &&
                                                                                choosenTransportType == 0 )
                                                                            ? Column(
                                                                                children: [
                                                                                  Container(
                                                                                    width: media.width * 0.9,
                                                                                    height: media.width * 0.1,
                                                                                    decoration: BoxDecoration(
                                                                                      borderRadius: BorderRadius.circular(media.width * 0.02),
                                                                                    ),
                                                                                    child: Row(
                                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                                      children: [
                                                                                        InkWell(
                                                                                          onTap: () {
                                                                                            ismulitipleride = false;
                                                                                            setState(() {
                                                                                              Navigator.pushAndRemoveUntil(
                                                                                                  context,
                                                                                                  MaterialPageRoute(
                                                                                                      builder: (context) => BookingConfirmation(
                                                                                                            type: 2,
                                                                                                          )),
                                                                                                  (route) => false);
                                                                                            });
                                                                                          },
                                                                                          child: Row(
                                                                                            children: [
                                                                                              Container(
                                                                                                padding: EdgeInsets.all(media.width * 0.01),
                                                                                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(media.width * 0.01)),
                                                                                                child: RotatedBox(
                                                                                                  quarterTurns: 3,
                                                                                                  child: Icon(
                                                                                                    Icons.route_sharp,
                                                                                                    color: textColor,
                                                                                                    size: media.width * sixteen,
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                              SizedBox(
                                                                                                width: media.width * 0.02,
                                                                                              ),
                                                                                              MyText(text: languages[choosenLanguage]['text_ridewithout_destination'], size: media.width * sixteen, fontweight: FontWeight.w600, color: (isDarkTheme == true) ? Colors.white : buttonColor),
                                                                                            ],
                                                                                          ),
                                                                                        )
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              )
                                                                            : Container()
                                                                      ],
                                                                    )
                                                                  : Container(),
                                                              (_bottom == 1)
                                                                  ? Expanded(
                                                                      child:
                                                                          Container(
                                                                      padding: EdgeInsets.all(
                                                                          media.width *
                                                                              0.03),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(media.width *
                                                                                0.02),
                                                                        color:
                                                                            page,
                                                                      ),
                                                                      child: SingleChildScrollView(
                                                                          physics: const BouncingScrollPhysics(),
                                                                          child: Column(
                                                                            children: [
                                                                              (addAutoFill.isNotEmpty)
                                                                                  ? Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: addAutoFill
                                                                                          .asMap()
                                                                                          .map((i, value) {
                                                                                            return MapEntry(
                                                                                                i,
                                                                                                (i < 5)
                                                                                                    ? Container(
                                                                                                        padding: EdgeInsets.fromLTRB(0, media.width * 0.04, 0, media.width * 0.04),
                                                                                                        decoration: BoxDecoration(
                                                                                                          border: Border(bottom: BorderSide(width: 1.0, color: (isDarkTheme == true) ? textColor.withOpacity(0.2) : textColor.withOpacity(0.1))),
                                                                                                        ),
                                                                                                        child: Row(
                                                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                          children: [
                                                                                                            SizedBox(
                                                                                                              height: media.width * 0.1,
                                                                                                              width: media.width * 0.1,
                                                                                                              child: Icon(Icons.access_time, color: textColor),
                                                                                                            ),
                                                                                                            InkWell(
                                                                                                              onTap: () async {
                                                                                                                // ignore: prefer_typing_uninitialized_variables
                                                                                                                var val;
                                                                                                                  val = await geoCodingForLatLng(addAutoFill[i]['description']);
                                                                                                                

                                                                                                                if (_pickaddress == true) {
                                                                                                                  setState(() {
                                                                                                                    if (addressList.where((element) => element.type == 'pickup').isEmpty) {
                                                                                                                      addressList.add(AddressList(id: '1', type: 'pickup', pickup: true, address: (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'], latlng: (addAutoFill[i]['description'] != null) ? val : LatLng(double.parse(addAutoFill[i]['lat'].toString()), double.parse(addAutoFill[i]['lon'].toString())), name: userDetails['name'], number: userDetails['mobile']));
                                                                                                                    } else {
                                                                                                                      addressList.firstWhere((element) => element.type == 'pickup').address = (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'];
                                                                                                                      addressList.firstWhere((element) => element.type == 'pickup').latlng = (addAutoFill[i]['description'] != null) ? val : LatLng(double.parse(addAutoFill[i]['lat'].toString()), double.parse(addAutoFill[i]['lon'].toString()));
                                                                                                                    }
                                                                                                                  });
                                                                                                                } else {
                                                                                                                  setState(() {
                                                                                                                    if (addressList.where((element) => element.type == 'drop').isEmpty) {
                                                                                                                      addressList.add(AddressList(id: '2', type: 'drop', pickup: false, address: (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'], latlng: (addAutoFill[i]['description'] != null) ? val : LatLng(double.parse(addAutoFill[i]['lat'].toString()), double.parse(addAutoFill[i]['lon'].toString()))));
                                                                                                                    } else {
                                                                                                                      addressList.firstWhere((element) => element.type == 'drop').address = (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'];
                                                                                                                      addressList.firstWhere((element) => element.type == 'drop').latlng = (addAutoFill[i]['description'] != null) ? val : LatLng(double.parse(addAutoFill[i]['lat'].toString()), double.parse(addAutoFill[i]['lon'].toString()));
                                                                                                                    }
                                                                                                                  });
                                                                                                                  if (addressList.length == 2) {
                                                                                                                    navigate();
                                                                                                                  }
                                                                                                                }
                                                                                                                setState(() {
                                                                                                                  addAutoFill.clear();
                                                                                                                  _dropaddress = false;

                                                                                                                  if (_pickaddress == true) {
                                                                                                                    center = val;
                                                                                                                    _controller?.moveCamera(CameraUpdate.newLatLngZoom(val, 14.0));
                                                                                                                  }
                                                                                                                  _height = media.width * 0.68;
                                                                                                                  _bottom = 0;
                                                                                                                  if (choosenTransportType == 2) {
                                                                                                                    choosenTransportType = 0;
                                                                                                                  }
                                                                                                                });
                                                                                                              },
                                                                                                              child: SizedBox(
                                                                                                                width: media.width * 0.65,
                                                                                                                child: MyText(text: (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'], size: media.width * twelve, maxLines: 2),
                                                                                                              ),
                                                                                                            ),
                                                                                                            (favAddress.length < 4)
                                                                                                                ? InkWell(
                                                                                                                    onTap: () async {
                                                                                                                      if (favAddress.where((e) => e['pick_address'] == addAutoFill[i]['description'] || e['pick_address'] == addAutoFill[i]['display_name']).isEmpty) {
                                                                                                                        // ignore: prefer_typing_uninitialized_variables
                                                                                                                        var val;
                                                                                                                        if (addAutoFill[i]['description'] != null) {
                                                                                                                          val = await geoCodingForLatLng(addAutoFill[i]['description']);
                                                                                                                        }
                                                                                                                        setState(() {
                                                                                                                          favSelectedAddress = (addAutoFill[i]['description'] != null) ? addAutoFill[i]['description'] : addAutoFill[i]['display_name'];
                                                                                                                          favLat = (addAutoFill[i]['description'] != null) ? val.latitude : double.parse(addAutoFill[i]['lat'].toString());
                                                                                                                          favLng = (addAutoFill[i]['description'] != null) ? val.longitude : double.parse(addAutoFill[i]['lon'].toString());
                                                                                                                          favAddressAdd = true;
                                                                                                                        });
                                                                                                                      }
                                                                                                                    },
                                                                                                                    child: Icon(
                                                                                                                      Icons.bookmark,
                                                                                                                      size: media.width * 0.05,
                                                                                                                      color: favAddress.where((element) => element['pick_address'] == addAutoFill[i]['description'] || element['pick_address'] == addAutoFill[i]['display_name']).isNotEmpty ? buttonColor : textColor.withOpacity(0.3),
                                                                                                                    ),
                                                                                                                  )
                                                                                                                : Container()
                                                                                                          ],
                                                                                                        ),
                                                                                                      )
                                                                                                    : Container());
                                                                                          })
                                                                                          .values
                                                                                          .toList(),
                                                                                    )
                                                                                  : Container(),
                                                                            ],
                                                                          )),
                                                                    ))
                                                                  : Container()
                                                            ],
                                                          ),
                                                        ),
                                                      )),
                                                  (_lastCenter == 0)
                                                      ? Positioned(
                                                          bottom: 0,
                                                          child: Container(
                                                            color: page,
                                                            padding: EdgeInsets
                                                                .all(media
                                                                        .width *
                                                                    0.05),
                                                            height:
                                                                media.width *
                                                                    0.35,
                                                            width:
                                                                media.width * 1,
                                                            child: Column(
                                                              children: [
                                                                InkWell(
                                                                  onTap: () {
                                                                    if (addressList
                                                                        .where((element) =>
                                                                            element.type ==
                                                                            'pickup')
                                                                        .isNotEmpty) {
                                                                      setState(
                                                                          () {
                                                                        _pickaddress =
                                                                            true;
                                                                        _dropaddress =
                                                                            false;
                                                                        addAutoFill
                                                                            .clear();
                                                                        _height =
                                                                            media.height *
                                                                                1;
                                                                      });

                                                                      Future.delayed(
                                                                          const Duration(
                                                                              milliseconds: 200),
                                                                          () {
                                                                        setState(
                                                                            () {
                                                                          _bottom =
                                                                              1;
                                                                        });
                                                                      });
                                                                    }
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    padding: EdgeInsets.all(
                                                                        media.width *
                                                                            0.01),
                                                                    decoration: BoxDecoration(
                                                                        color:
                                                                            page,
                                                                        borderRadius:
                                                                            BorderRadius.circular(media.width *
                                                                                0.01),
                                                                        border: Border.all(
                                                                            color:
                                                                                hintColor)),
                                                                    height:
                                                                        media.width *
                                                                            0.1,
                                                                    width: media
                                                                            .width *
                                                                        0.9,
                                                                    child: Row(
                                                                      children: [
                                                                        Container(
                                                                          height:
                                                                              media.width * 0.05,
                                                                          width:
                                                                              media.width * 0.05,
                                                                          alignment:
                                                                              Alignment.center,
                                                                          decoration: const BoxDecoration(
                                                                              shape: BoxShape.circle,
                                                                              color: Colors.green),
                                                                          child:
                                                                              Container(
                                                                            height:
                                                                                media.width * 0.02,
                                                                            width:
                                                                                media.width * 0.02,
                                                                            decoration:
                                                                                BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.6)),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                            width:
                                                                                media.width * 0.02),
                                                                        Expanded(
                                                                          child:
                                                                              MyText(
                                                                            text: (addressList.where((element) => element.type == 'pickup').isNotEmpty)
                                                                                ? addressList.firstWhere((element) => element.type == 'pickup', orElse: () => AddressList(id: '', address: '', pickup: true, latlng: const LatLng(0.0, 0.0))).address
                                                                                : languages[choosenLanguage]['text_4letterpickup'],
                                                                            size:
                                                                                media.width * fourteen,
                                                                            color:
                                                                                textColor,
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: media
                                                                          .width *
                                                                      0.02,
                                                                ),
                                                                ShowUpWidget(
                                                                  delay: 100,
                                                                  child: Button(
                                                                      borderRadius:
                                                                          0.0,
                                                                      height:
                                                                          media.width *
                                                                              0.1,
                                                                      onTap:
                                                                          () async {
                                                                        // if (ischanged) {
                                                                        setState(
                                                                            () {
                                                                          _lastCenter =
                                                                              _centerLocation;

                                                                          ischanged =
                                                                              false;
                                                                        });
                                                                        // }
                                                                      },
                                                                      text: languages[
                                                                              choosenLanguage]
                                                                          [
                                                                          'text_confirm']),
                                                                )
                                                              ],
                                                            ),
                                                          ))
                                                      : Container()
                                                ],
                                              )
                                            : Container(),
                              ]),
                        ),

                        //add fav address
                        (favAddressAdd == true)
                            ? Positioned(
                                top: 0,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      favAddressAdd = false;
                                    });
                                  },
                                  child: Container(
                                    height: media.height * 1,
                                    width: media.width * 1,
                                    color: Colors.transparent.withOpacity(0.6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.fromLTRB(
                                              media.width * 0.05,
                                              media.width * 0.05,
                                              media.width * 0.05,
                                              MediaQuery.of(context)
                                                      .viewInsets
                                                      .bottom +
                                                  media.width * 0.05),
                                          width: media.width * 1,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(12),
                                                      topRight:
                                                          Radius.circular(12)),
                                              color: page),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  MyText(
                                                    text: languages[
                                                            choosenLanguage]
                                                        ['text_add_address'],
                                                    size: media.width * sixteen,
                                                    fontweight: FontWeight.w600,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: media.width * 0.025,
                                              ),
                                              Container(
                                                width: media.width * 0.9,
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    boxShadow: [
                                                      BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          blurRadius: 2,
                                                          spreadRadius: 2)
                                                    ],
                                                    color: topBar),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      height:
                                                          media.width * 0.064,
                                                      width:
                                                          media.width * 0.064,
                                                      decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: const Color(
                                                                  0xffFF0000)
                                                              .withOpacity(
                                                                  0.1)),
                                                      child: Icon(
                                                        Icons.place,
                                                        size:
                                                            media.width * 0.04,
                                                        color: const Color(
                                                            0xffFF0000),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: media.width * 0.02,
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        favSelectedAddress,
                                                        style: GoogleFonts.notoSans(
                                                            fontSize:
                                                                media.width *
                                                                    twelve,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                (isDarkTheme ==
                                                                        true)
                                                                    ? Colors
                                                                        .black
                                                                    : textColor),
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                height: media.width * 0.025,
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                      setState(() {
                                                        favName = 'Home';
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              media.width *
                                                                  0.05,
                                                              media.width *
                                                                  0.02,
                                                              media.width *
                                                                  0.05,
                                                              media.width *
                                                                  0.02),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        border: Border.all(
                                                            color: (favName ==
                                                                    'Home')
                                                                ? buttonColor
                                                                : borderLines,
                                                            width: 1.1),
                                                        color: (favName ==
                                                                'Home')
                                                            ? buttonColor
                                                            : Colors
                                                                .transparent,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .home_outlined,
                                                              size:
                                                                  media.width *
                                                                      0.05,
                                                              color: (favName ==
                                                                      'Home')
                                                                  ? (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white
                                                                  : (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black),
                                                          SizedBox(
                                                            width: media.width *
                                                                0.01,
                                                          ),
                                                          MyText(
                                                              text: languages[
                                                                      choosenLanguage]
                                                                  ['text_home'],
                                                              size:
                                                                  media.width *
                                                                      twelve,
                                                              color: (favName ==
                                                                      'Home')
                                                                  ? (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white
                                                                  : (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black)
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                      setState(() {
                                                        favName = 'Work';
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              media.width *
                                                                  0.05,
                                                              media.width *
                                                                  0.02,
                                                              media.width *
                                                                  0.05,
                                                              media.width *
                                                                  0.02),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        border: Border.all(
                                                            color: (favName ==
                                                                    'Work')
                                                                ? buttonColor
                                                                : borderLines,
                                                            width: 1.1),
                                                        color: (favName ==
                                                                'Work')
                                                            ? buttonColor
                                                            : Colors
                                                                .transparent,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .work_outline_outlined,
                                                              size:
                                                                  media.width *
                                                                      0.05,
                                                              color: (favName ==
                                                                      'Work')
                                                                  ? (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white
                                                                  : (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black),
                                                          SizedBox(
                                                            width: media.width *
                                                                0.01,
                                                          ),
                                                          MyText(
                                                              text: languages[
                                                                      choosenLanguage]
                                                                  ['text_work'],
                                                              size:
                                                                  media.width *
                                                                      twelve,
                                                              color: (favName ==
                                                                      'Work')
                                                                  ? (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white
                                                                  : (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black)
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                      setState(() {
                                                        favName = 'Others';
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              media.width *
                                                                  0.05,
                                                              media.width *
                                                                  0.02,
                                                              media.width *
                                                                  0.05,
                                                              media.width *
                                                                  0.02),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        border: Border.all(
                                                            color: (favName ==
                                                                    'Others')
                                                                ? buttonColor
                                                                : borderLines,
                                                            width: 1.1),
                                                        color: (favName ==
                                                                'Others')
                                                            ? buttonColor
                                                            : Colors
                                                                .transparent,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .bookmark_outline,
                                                              size:
                                                                  media.width *
                                                                      0.05,
                                                              color: (favName ==
                                                                      'Others')
                                                                  ? (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white
                                                                  : (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black),
                                                          SizedBox(
                                                            width: media.width *
                                                                0.01,
                                                          ),
                                                          MyText(
                                                              text:
                                                                  'Create New',
                                                              size:
                                                                  media.width *
                                                                      twelve,
                                                              color: (favName ==
                                                                      'Others')
                                                                  ? (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white
                                                                  : (isDarkTheme ==
                                                                          true)
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black)
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              (favName == 'Others')
                                                  ? Container(
                                                      margin: EdgeInsets.only(
                                                          top: media.width *
                                                              0.03),
                                                      padding: EdgeInsets.all(
                                                          media.width * 0.025),
                                                      decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color:
                                                                  borderLines,
                                                              width: 1.2)),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            hintText: languages[
                                                                    choosenLanguage]
                                                                [
                                                                'text_enterfavname'],
                                                            hintStyle: GoogleFonts.notoSans(
                                                                fontSize: media
                                                                        .width *
                                                                    twelve,
                                                                color:
                                                                    hintColor)),
                                                        maxLines: 1,
                                                        onChanged: (val) {
                                                          setState(() {
                                                            favNameText = val;
                                                          });
                                                        },
                                                      ),
                                                    )
                                                  : Container(),
                                              SizedBox(
                                                height: media.width * 0.05,
                                              ),
                                              Button(
                                                  onTap: () async {
                                                    if (favName == 'Others' &&
                                                        favNameText != '') {
                                                      setState(() {
                                                        _loading = true;
                                                      });
                                                      var val =
                                                          await addFavLocation(
                                                              favLat,
                                                              favLng,
                                                              favSelectedAddress,
                                                              favNameText);
                                                      setState(() {
                                                        _loading = false;
                                                        if (val == true) {
                                                          favLat = '';
                                                          favLng = '';
                                                          favSelectedAddress =
                                                              '';
                                                          favName = 'Home';
                                                          favNameText = '';
                                                          favAddressAdd = false;
                                                        } else if (val ==
                                                            'logout') {
                                                          navigateLogout();
                                                        }
                                                      });
                                                    } else if (favName ==
                                                            'Home' ||
                                                        favName == 'Work') {
                                                      setState(() {
                                                        _loading = true;
                                                      });
                                                      var val =
                                                          await addFavLocation(
                                                              favLat,
                                                              favLng,
                                                              favSelectedAddress,
                                                              favName);
                                                      setState(() {
                                                        _loading = false;
                                                        if (val == true) {
                                                          favLat = '';
                                                          favLng = '';
                                                          favName = 'Home';
                                                          favSelectedAddress =
                                                              '';
                                                          favNameText = '';
                                                          favAddressAdd = false;
                                                        } else if (val ==
                                                            'logout') {
                                                          navigateLogout();
                                                        }
                                                      });
                                                    }
                                                  },
                                                  text:
                                                      languages[choosenLanguage]
                                                          ['text_confirm'])
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ))
                            : Container(),

                        //driver cancelled request
                        (requestCancelledByDriver == true)
                            ? Positioned(
                                top: 0,
                                child: Container(
                                  height: media.height * 1,
                                  width: media.width * 1,
                                  color: Colors.transparent.withOpacity(0.6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: media.width * 0.9,
                                        padding:
                                            EdgeInsets.all(media.width * 0.05),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: page),
                                        child: Column(
                                          children: [
                                            Text(
                                              languages[choosenLanguage]
                                                  ['text_drivercancelled'],
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * fourteen,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.05,
                                            ),
                                            Button(
                                                onTap: () {
                                                  setState(() {
                                                    requestCancelledByDriver =
                                                        false;
                                                    userRequestData = {};
                                                  });
                                                },
                                                text: languages[choosenLanguage]
                                                    ['text_ok'])
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ))
                            : Container(),

                        //user cancelled request
                        (cancelRequestByUser == true)
                            ? Positioned(
                                top: 0,
                                child: Container(
                                  height: media.height * 1,
                                  width: media.width * 1,
                                  color: Colors.transparent.withOpacity(0.6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: media.width * 0.9,
                                        padding:
                                            EdgeInsets.all(media.width * 0.05),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: page),
                                        child: Column(
                                          children: [
                                            Text(
                                              languages[choosenLanguage]
                                                  ['text_cancelsuccess'],
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * fourteen,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.05,
                                            ),
                                            Button(
                                                onTap: () {
                                                  setState(() {
                                                    cancelRequestByUser = false;
                                                    userRequestData = {};
                                                  });
                                                },
                                                text: languages[choosenLanguage]
                                                    ['text_ok'])
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ))
                            : Container(),

                        //delete account
                        (deleteAccount == true)
                            ? Positioned(
                                top: 0,
                                child: Container(
                                  height: media.height * 1,
                                  width: media.width * 1,
                                  color: Colors.transparent.withOpacity(0.6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: media.width * 0.9,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                                height: media.height * 0.1,
                                                width: media.width * 0.1,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: page),
                                                child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        deleteAccount = false;
                                                      });
                                                    },
                                                    child: Icon(
                                                        Icons.cancel_outlined,
                                                        color: textColor))),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            EdgeInsets.all(media.width * 0.05),
                                        width: media.width * 0.9,
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: page),
                                        child: Column(
                                          children: [
                                            Text(
                                              languages[choosenLanguage]
                                                  ['text_delete_confirm'],
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * sixteen,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.05,
                                            ),
                                            Button(
                                                onTap: () async {
                                                  setState(() {
                                                    deleteAccount = false;
                                                    _loading = true;
                                                  });
                                                  var result =
                                                      await userDelete();
                                                  if (result == 'success') {
                                                    setState(() {
                                                      Navigator.pushAndRemoveUntil(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const Login()),
                                                          (route) => false);
                                                      userDetails.clear();
                                                    });
                                                  } else if (result ==
                                                      'logout') {
                                                    navigateLogout();
                                                  } else {
                                                    setState(() {
                                                      _loading = false;
                                                      deleteAccount = true;
                                                    });
                                                  }
                                                  setState(() {
                                                    _loading = false;
                                                  });
                                                },
                                                text: languages[choosenLanguage]
                                                    ['text_confirm'])
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ))
                            : Container(),

                        //logout
                        (logout == true)
                            ? Positioned(
                                top: 0,
                                child: Container(
                                  height: media.height * 1,
                                  width: media.width * 1,
                                  color: Colors.transparent.withOpacity(0.6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: media.width * 0.9,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                                height: media.height * 0.1,
                                                width: media.width * 0.1,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: page),
                                                child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        logout = false;
                                                      });
                                                    },
                                                    child: Icon(
                                                        Icons.cancel_outlined,
                                                        color: textColor))),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            EdgeInsets.all(media.width * 0.05),
                                        width: media.width * 0.9,
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            color: page),
                                        child: Column(
                                          children: [
                                            Text(
                                              languages[choosenLanguage]
                                                  ['text_confirmlogout'],
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.notoSans(
                                                  fontSize:
                                                      media.width * sixteen,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.05,
                                            ),
                                            Button(
                                                onTap: () async {
                                                  setState(() {
                                                    logout = false;
                                                    _loading = true;
                                                  });
                                                  var result =
                                                      await userLogout();
                                                  if (result == 'success' ||
                                                      result == 'logout') {
                                                    setState(() {
                                                      Navigator.pushAndRemoveUntil(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const Login()),
                                                          (route) => false);
                                                      userDetails.clear();
                                                    });
                                                  } else {
                                                    setState(() {
                                                      _loading = false;
                                                      logout = true;
                                                    });
                                                  }
                                                  setState(() {
                                                    _loading = false;
                                                  });
                                                },
                                                text: languages[choosenLanguage]
                                                    ['text_confirm'])
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ))
                            : Container(),
                        (_locationDenied == true)
                            ? Positioned(
                                child: Container(
                                height: media.height * 1,
                                width: media.width * 1,
                                color: Colors.transparent.withOpacity(0.6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: media.width * 0.9,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _locationDenied = false;
                                              });
                                            },
                                            child: Container(
                                              height: media.height * 0.05,
                                              width: media.height * 0.05,
                                              decoration: BoxDecoration(
                                                color: page,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.cancel,
                                                  color: buttonColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: media.width * 0.025),
                                    Container(
                                      padding:
                                          EdgeInsets.all(media.width * 0.05),
                                      width: media.width * 0.9,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: page,
                                          boxShadow: [
                                            BoxShadow(
                                                blurRadius: 2.0,
                                                spreadRadius: 2.0,
                                                color: Colors.black
                                                    .withOpacity(0.2))
                                          ]),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                              width: media.width * 0.8,
                                              child: Text(
                                                languages[choosenLanguage]
                                                    ['text_open_loc_settings'],
                                                style: GoogleFonts.notoSans(
                                                    fontSize:
                                                        media.width * sixteen,
                                                    color: textColor,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              )),
                                          SizedBox(height: media.width * 0.05),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              InkWell(
                                                  onTap: () async {
                                                    await perm
                                                        .openAppSettings();
                                                  },
                                                  child: Text(
                                                    languages[choosenLanguage]
                                                        ['text_open_settings'],
                                                    style: GoogleFonts.notoSans(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: buttonColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  )),
                                              InkWell(
                                                  onTap: () async {
                                                    setState(() {
                                                      _locationDenied = false;
                                                      _loading = true;
                                                    });

                                                    getLocs();
                                                  },
                                                  child: Text(
                                                    languages[choosenLanguage]
                                                        ['text_done'],
                                                    style: GoogleFonts.notoSans(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: buttonColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ))
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ))
                            : Container(),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 1),
                          bottom: _isbottom,
                          child: InkWell(
                            onTap: () {
                              Future.delayed(const Duration(milliseconds: 200),
                                  () {
                                setState(() {
                                  choosenTransportType = 0;
                                  _isbottom = -1000;
                                });
                              });
                              setState(() {
                                _outstationheight = 0;
                              });
                            },
                            child: Container(
                              height: media.height * 1,
                              width: media.width * 1,
                              color: Colors.black.withOpacity(0.3),
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                padding: EdgeInsets.all(media.width * 0.05),
                                duration: const Duration(milliseconds: 200),
                                width: media.width * 1,
                                height: _outstationheight == 0
                                    ? 0
                                    : _outstationheight,
                                color: page,
                                constraints: BoxConstraints(
                                    minHeight: 0,
                                    maxHeight: media.height * 0.8),
                                curve: Curves.easeOut,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MyText(
                                        text: languages[choosenLanguage]
                                            ['text_chooe_transport_type'],
                                        size: media.width * sixteen,
                                        fontweight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                      SizedBox(
                                        height: media.width * 0.02,
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (choosenTransportType == 3) {
                                            if (addressList.isNotEmpty) {
                                              choosenTransportType = 0;
                                              ismulitipleride = false;
                                              Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          BookingConfirmation(
                                                            type: 1,
                                                          )),
                                                  (route) => false);
                                            }
                                          } else {
                                            _height = media.height * 1;
                                            _outstationheight = 0;
                                            _isbottom = -1000;
                                            transportType = 'taxi';

                                            choosenTransportType = 0;

                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 200), () {
                                              setState(() {
                                                _bottom = 1;
                                                _dropaddress = true;
                                              });
                                            });
                                            setState(() {});
                                          }
                                        },
                                        child: Container(
                                          height: media.width * 0.15,
                                          width: media.width * 0.9,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      media.width * 0.02),
                                              color: page,
                                              border:
                                                  Border.all(color: hintColor)),
                                          child: Row(
                                            children: [
                                              Container(
                                                height: media.width * 0.15,
                                                width: media.width * 0.2,
                                                alignment: Alignment.centerLeft,
                                                decoration: const BoxDecoration(
                                                  image: DecorationImage(
                                                      image: AssetImage(
                                                          'assets/images/taxi.png')),
                                                ),
                                              ),
                                              Expanded(
                                                child: MyText(
                                                    text: 'Taxi',
                                                    size:
                                                        media.width * sixteen),
                                              ),
                                              RotatedBox(
                                                  quarterTurns: 4,
                                                  child: Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: media.width * 0.05,
                                                  ))
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: media.width * 0.02,
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (choosenTransportType == 3) {
                                            if (addressList.isNotEmpty) {
                                              choosenTransportType = 1;
                                              ismulitipleride = false;
                                              Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          BookingConfirmation(
                                                            type: 1,
                                                          )),
                                                  (route) => false);
                                            }
                                          } else {
                                            setState(() {
                                              _height = media.height * 1;
                                              _outstationheight = 0;
                                              _isbottom = -1000;
                                              transportType = 'delivery';
                                              choosenTransportType = 1;
                                            });
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 200), () {
                                              setState(() {
                                                _bottom = 1;
                                                _dropaddress = true;
                                              });
                                            });
                                          }
                                        },
                                        child: Container(
                                          height: media.width * 0.15,
                                          width: media.width * 0.9,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      media.width * 0.02),
                                              color: page,
                                              border:
                                                  Border.all(color: hintColor)),
                                          child: Row(
                                            children: [
                                              Container(
                                                height: media.width * 0.15,
                                                width: media.width * 0.2,
                                                alignment: Alignment.centerLeft,
                                                decoration: const BoxDecoration(
                                                  image: DecorationImage(
                                                      image: AssetImage(
                                                          'assets/images/delivery.png')),
                                                ),
                                              ),
                                              Expanded(
                                                child: MyText(
                                                    text: 'Delivery',
                                                    size:
                                                        media.width * sixteen),
                                              ),
                                              RotatedBox(
                                                  quarterTurns: 4,
                                                  child: Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: media.width * 0.05,
                                                  ))
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        //loader
                        (_loading == true || state == '')
                            ? const Positioned(top: 0, child: Loading())
                            : Container(),
                        (internet == false)
                            ? Positioned(
                                top: 0,
                                child: NoInternet(
                                  onTap: () {
                                    setState(() {
                                      internetTrue();
                                      getUserDetails();
                                    });
                                  },
                                ))
                            : Container()
                      ],
                    ),
                  ),
                );
              }),
        ),
      ),
    );
  }

  double getBearing(LatLng begin, LatLng end) {
    double lat = (begin.latitude - end.latitude).abs();

    double lng = (begin.longitude - end.longitude).abs();

    if (begin.latitude < end.latitude && begin.longitude < end.longitude) {
      return vector.degrees(atan(lng / lat));
    } else if (begin.latitude >= end.latitude &&
        begin.longitude < end.longitude) {
      return (90 - vector.degrees(atan(lng / lat))) + 90;
    } else if (begin.latitude >= end.latitude &&
        begin.longitude >= end.longitude) {
      return vector.degrees(atan(lng / lat)) + 180;
    } else if (begin.latitude < end.latitude &&
        begin.longitude >= end.longitude) {
      return (90 - vector.degrees(atan(lng / lat))) + 270;
    }

    return -1;
  }

  animateCar(
      double fromLat, //Starting latitude

      double fromLong, //Starting longitude

      double toLat, //Ending latitude

      double toLong, //Ending longitude

      StreamSink<List<Marker>>
          mapMarkerSink, //Stream build of map to update the UI

      TickerProvider
          provider, //Ticker provider of the widget. This is used for animation

      // GoogleMapController controller, //Google map controller of our widget

      markerid,
      markerBearing,
      icon) async {
    final double bearing =
        getBearing(LatLng(fromLat, fromLong), LatLng(toLat, toLong));

    myBearings[markerBearing.toString()] = bearing;

    var carMarker = Marker(
        markerId: MarkerId(markerid),
        position: LatLng(fromLat, fromLong),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        draggable: false);

    myMarkers.add(carMarker);

    mapMarkerSink.add(Set<Marker>.from(myMarkers).toList());

    Tween<double> tween = Tween(begin: 0, end: 1);

    _animation = tween.animate(animationController)
      ..addListener(() async {
        myMarkers
            .removeWhere((element) => element.markerId == MarkerId(markerid));

        final v = _animation!.value;

        double lng = v * toLong + (1 - v) * fromLong;

        double lat = v * toLat + (1 - v) * fromLat;

        LatLng newPos = LatLng(lat, lng);

        //New marker location

        carMarker = Marker(
            markerId: MarkerId(markerid),
            position: newPos,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            rotation: bearing,
            draggable: false);

        //Adding new marker to our list and updating the google map UI.

        myMarkers.add(carMarker);

        mapMarkerSink.add(Set<Marker>.from(myMarkers).toList());
      });

    //Starting the animation

    animationController.forward();
  }
}

class Debouncer {
  final int milliseconds;
  dynamic action;
  dynamic _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    if (null != _timer) {
      _timer.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class BannerImage extends StatefulWidget {
  const BannerImage({super.key});

  @override
  State<BannerImage> createState() => _BannerImageState();
}

class _BannerImageState extends State<BannerImage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  Timer? timer;
  bool end = false;
  @override
  void initState() {
    super.initState();

    if (banners.length != 1) {
      timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
        if (_currentPage == banners.length - 1) {
          end = true;
        } else if (_currentPage == 0) {
          end = false;
        }

        if (end == false) {
          _currentPage++;
        } else {
          _currentPage--;
        }

        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: (banners.length == 1)
          ? Image.network(
              banners[0]['image'],
              fit: BoxFit.fitWidth,
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              itemBuilder: (context, index) {
                return Image.network(
                  banners[index]['image'],
                  fit: BoxFit.fitWidth,
                );
              },
            ),
    );
  }
}
