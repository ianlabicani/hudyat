// Throwaway hour-one test app (spec 3.3). Not product code: nothing in lib/
// of the main app may import from here.
import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import 'map_test_page.dart';
import 'model_test_page.dart';
import 'notification_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterEdgeAi.initialize(
    inferenceEngines: const [LiteRtLmEngine()],
    embeddingBackends: const [LiteRtEmbeddingBackend()],
    embeddingTokenizers: const [GemmaEmbeddingTokenizers()],
  );
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hudyat model test',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.brown)),
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          // The AppBar keeps the tabs below the status bar.
          appBar: AppBar(
            toolbarHeight: 0,
            bottom: const TabBar(
              labelColor: Colors.black,
              tabs: [
                Tab(text: 'Models'),
                Tab(text: 'Map'),
                Tab(text: 'Notifs'),
              ],
            ),
          ),
          body: const SafeArea(
            child: TabBarView(
              physics: NeverScrollableScrollPhysics(),
              children: [
                ModelTestPage(),
                MapTestPage(),
                NotificationTestPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
