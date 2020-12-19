import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import the firebase_core and cloud_firestore plugin
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  String userRaw = await (rootBundle.loadString("UserCredential.json"));
  var user = jsonDecode(userRaw);
  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: user["email"],
        password: user["password"]
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      print('No user found for that email.');
    } else if (e.code == 'wrong-password') {
      print('Wrong password provided for that user.');
    }
  }
  runApp(MyApp());
}

DateTime selectedDate = DateTime.now();

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData.dark(),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> _incrementCounter() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _incrementCounter,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Container(
              padding: EdgeInsets.all(8),
              height: MediaQuery.of(context).size.height -
                  AppBar().preferredSize.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  20,
              child: Column(
                children: <Widget>[
                  Text(
                    "${selectedDate.toLocal()}".split(' ')[0],
                    style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    flex: 1,
                    child: GetUserName("0DL2zXF4YaXFzwHWXhcI"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectDate(context),
        tooltip: 'Increment',
        child: Icon(Icons.date_range),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

// GetUserName("0DL2zXF4YaXFzwHWXhcI"),
  _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: selectedDate, // Refer step 1
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }
}

class GetUserName extends StatelessWidget {
  final String documentId;

  GetUserName(this.documentId);

  @override
  Widget build(BuildContext context) {
    DateTime _now = DateTime.now();
    DateTime _start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0);
    DateTime _end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    CollectionReference users = FirebaseFirestore.instance.collection('HomeTemperatures');

    return FutureBuilder<QuerySnapshot>(
      future: users.where('time', isGreaterThanOrEqualTo: _start).where('time', isLessThanOrEqualTo: _end).orderBy("time").get(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Text(snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.done) {
          List<QueryDocumentSnapshot> datas = snapshot.data.docs;
          var str = "";
          for (int i = 0; i < datas.length; i++) {
            str += "Temp: ${datas[i]['temperature']}, Hum: ${datas[i]['humidity']}, Time: ${datas[i]['time'].toDate()}\n";
          }
          //return Text(str);
          return GroupedBarChart(datas);
        }

        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class GroupedBarChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> seriesList;
  final bool animate;

  GroupedBarChart(this.seriesList, {this.animate});

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    bool darkModeOn = brightness == Brightness.dark;

    return new charts.BarChart(
      _createSampleData(),
      animate: animate,
      barGroupingType: charts.BarGroupingType.grouped,
      primaryMeasureAxis: new charts.NumericAxisSpec(
        tickProviderSpec: new charts.BasicNumericTickProviderSpec(desiredTickCount: 10),
          renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec( color: darkModeOn ? charts.MaterialPalette.white : charts.MaterialPalette.black),
          ),
      ),
      domainAxis: charts.AxisSpec<String>(
        renderSpec: charts.GridlineRendererSpec(
          labelStyle: charts.TextStyleSpec(color: darkModeOn ? charts.MaterialPalette.white : charts.MaterialPalette.black),
        ),
      ),
    );
  }

  /// Create series list with multiple series
  List<charts.Series<OrdinalSales, String>> _createSampleData() {
    List<OrdinalSales> tempData = [];
    for (var data in seriesList) {
      DateTime time = data["time"].toDate();
      double temp = data["temperature"];
      tempData.add(new OrdinalSales(time.hour.toString(), temp.toInt()));
    }
    List<OrdinalSales> humData = [];
    for (var data in seriesList) {
      DateTime time = data["time"].toDate();
      double hum = data["humidity"];
      humData.add(new OrdinalSales(time.hour.toString(), hum.toInt()));
    }
    return [
      new charts.Series<OrdinalSales, String>(
        id: 'Temperature',
        seriesColor: charts.MaterialPalette.red.shadeDefault,
        domainFn: (OrdinalSales sales, _) => sales.year,
        measureFn: (OrdinalSales sales, _) => sales.sales,
        data: tempData,
      ),
      new charts.Series<OrdinalSales, String>(
        id: 'Humidity',
        domainFn: (OrdinalSales sales, _) => sales.year,
        measureFn: (OrdinalSales sales, _) => sales.sales,
        data: humData,
      ),
    ];
  }
}

/// Sample ordinal data type.
class OrdinalSales {
  final String year;
  final int sales;

  OrdinalSales(this.year, this.sales);
}
