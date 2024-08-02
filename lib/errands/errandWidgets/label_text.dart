import 'package:flutter/material.dart';

class LabelText extends StatelessWidget {
  final String text;
  const LabelText({super.key,required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,style:TextStyle(fontWeight:FontWeight.bold,fontSize:16.0))
      ],
    );
  }
}