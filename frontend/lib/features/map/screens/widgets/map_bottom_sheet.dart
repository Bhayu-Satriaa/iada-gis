import 'package:flutter/material.dart';
import 'map_view.dart';

void showMapBottomSheet(BuildContext context, Map<String, dynamic> geoJson) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      final screenHeight = MediaQuery.of(context).size.height;

      return Container(
        height: screenHeight * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20)
          )
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.green[300],
                      borderRadius: BorderRadius.circular(10)
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.black54,)
                    ),
                  )
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Data Spasial Ditemukan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),

            Expanded(child: MapView(geoJson: geoJson))
          ],
        ),
      );
    },
  );
}