import 'package:example/logging.dart';
import 'package:example/model.dart';
import 'package:flutter/material.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';

void main() {
  setupLoggingPrintRecord();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: SimpleCounter(),
    );
  }
}

class SimpleCounter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = SimpleJsonPersistence.getForTypeSync(
      (json) => AppData.fromJson(json),
      defaultCreator: () => AppData(counter: 0),
      name: 'AppData',
    );
    return StreamBuilder<AppData?>(
        stream: store.onValueChangedAndLoad,
        initialData: store.cachedValue,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: const Text('SimpleJsonPersistence Example'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: data == null
                      ? <Widget>[
                          const Center(child: CircularProgressIndicator())
                        ]
                      : <Widget>[
                          const Text(
                            'You have pushed the button:',
                            textAlign: TextAlign.center,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${data.counter}',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const Text(' times')
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Value will be persistet on every touch, so feel free to restart the app at any time.',
                            textScaler: TextScaler.linear(0.75),
                            textAlign: TextAlign.center,
                          ),
                        ],
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () =>
                  store.save(AppData(counter: (data?.counter ?? 0) + 1)),
              tooltip: 'Increment',
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}
