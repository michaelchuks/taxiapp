import 'package:flutter/material.dart';

class DocumentList extends StatefulWidget {
  final dynamic riderId;
  final dynamic amount;
  const DocumentList({super.key,required this.amount,required this.riderId});

  @override
  State<DocumentList> createState() => _DocumentListState(amount,riderId);
}

class _DocumentListState extends State<DocumentList> {
  dynamic riderId;
  dynamic amount;
  _DocumentListState(this.amount,this.riderId);
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}