import 'dart:convert';

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
  late final HttpApiConfig apiConfig;
  late final HttpApi httpApi;
  String? hotCoffee;
  String? hotCoffeeImage;
  bool isLoadingCoffee = false;

  @override
  void initState() {
    apiConfig = HttpApiConfig(
      baseApiUrl: "https://api.sampleapis.com/",
      maxRetryAttempts: 3,
    );
    httpApi = HttpApi(httpApiConfig: apiConfig);
    super.initState();
  }

  Future<Result<String, Exception>> getHotCoffee() async {
    setState(() {
      isLoadingCoffee = true;
    });
    var res = await httpApi.get('coffee/hot');

    if (res?.statusCode == 200 && res?.body != null) {
      setState(() {
        isLoadingCoffee = false;
        hotCoffee = jsonDecode(res!.body)[0]['title'];
        hotCoffeeImage = jsonDecode(res.body)[0]['image'];
      });
      return Success(res!.body);
    }

    setState(() {
      isLoadingCoffee = false;
    });
    return Failure(Exception("No hot coffee found"));
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
                          onPressed: getHotCoffee,
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
