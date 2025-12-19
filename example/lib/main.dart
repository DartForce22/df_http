import 'dart:convert';
import 'dart:developer';

import 'package:df_http/df_http.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final DfHttpClientConfig apiConfig;
  late final DfApiClient httpApi;
  String? hotCoffee;
  String? hotCoffeeImage;
  bool isLoadingCoffee = false;

  @override
  void initState() {
    //Api config
    apiConfig = DfHttpClientConfig(
      baseApiUrl: "https://api.sample2apis.com/",
      maxRetryAttempts: 3,
    );
    httpApi = DfApiClient(httpApiConfig: apiConfig);
    super.initState();
  }

  //API Call
  //Instead of the List<dynamic> in Result should be model class, this is used just for an example API call
  Future<Result<List<dynamic>, Exception>> getHotCoffee() async {
    var res = await httpApi.get('coffee/hot');

    if (res?.statusCode == 200 && res?.body != null) {
      return Success(jsonDecode(res!.body));
    }
    return Failure(Exception("No hot coffee found"));
  }

  void onGetHotCoffeePress() async {
    setState(() {
      isLoadingCoffee = true;
    });
    var res = await getHotCoffee();

    switch (res) {
      case Success(value: final value):
        setState(() {
          isLoadingCoffee = false;
          hotCoffee = value[0]['title'];
          hotCoffeeImage = value[0]['image'];
        });
        break;
      case Failure(exception: final exception):
        log(exception.toString());
        setState(() {
          isLoadingCoffee = false;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          color: Colors.amberAccent,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: isLoadingCoffee
                ? CircularProgressIndicator()
                : SingleChildScrollView(
                    child: Column(
                      spacing: 4,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hotCoffee ?? "Waiting for coffee...",
                          style: TextStyle(color: Colors.white, fontSize: 36),
                        ),
                        if (hotCoffeeImage != null)
                          Image.network(hotCoffeeImage!),
                        ElevatedButton(
                          onPressed: onGetHotCoffeePress,
                          child: Text("Get Hot Coffee"),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
