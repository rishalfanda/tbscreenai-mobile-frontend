Strategi yang paling tepat adalah membangun **Dynamic DAG (Directed Acyclic Graph) Execution Engine** di dalam aplikasi. Dengan pendekatan ini, aplikasi tidak perlu mengetahui nama atau jenis model secara spesifik, melainkan hanya membaca relasi dependensi input-output dari `manifest.json`.

---

### 1. Rekonstruksi Dependensi Graf dari Manifest

Setiap elemen pada `pipeline` dianalisis untuk memetakan dari mana inputnya berasal:

* Input berawalan `@input`: Dependensi ke input awal sistem (gambar mentah).
* Input berformat `<node_id>.<output_name>`: Dependensi ke output dari node tertentu.

Dari aturan ini, setiap node memiliki daftar *parent* (prasyarat) yang harus selesai sebelum node tersebut dapat dieksekusi.

---

### 2. Pendekatan Eksekusi: Event-Driven `Future` / `Completer`

Pendekatan paling bersih di Dart/Flutter untuk mengeksekusi DAG secara dinamis tanpa loop polling adalah memanfaatkan **`Completer`**. Setiap node graf diwakili oleh sebuah `Completer<Map<String, dynamic>>`:

1. Buat peta `Completer` untuk setiap node ID: `Map<String, Completer<NodeOutput>>`.
2. Setiap node mendaftarkan tugasnya sebagai fungsi *async*.
3. Sebelum mulai, node menunggu penyelesaian semua parent-nya via `Future.wait(...)`.
4. Begitu parent selesai, node mengambil tensor yang dibutuhkan, menjalankan inferensi, lalu memanggil `completer.complete(outputTensor)`.
5. Node-node yang tidak saling bergantung akan otomatis dieksekusi secara paralel oleh runtime Dart.

```dart
class PipelineRunner {
  final Map<String, dynamic> manifest;
  PipelineRunner(this.manifest);

  Future<Map<String, dynamic>> execute(dynamic rawInput) async {
    final List pipeline = manifest['pipeline'];
    final Map<String, Completer<Map<String, dynamic>>> nodeCompleters = {
      for (var step in pipeline) step['id']: Completer<Map<String, dynamic>>()
    };

    // Trigger semua node secara bersamaan; eksekusi tertahan oleh dependensi masing-masing
    for (var step in pipeline) {
      _scheduleNode(
        step: step,
        rawInput: rawInput,
        nodeCompleters: nodeCompleters,
      );
    }

    // Tunggu node terakhir / output akhir yang didefinisikan di manifest
    final outputsDef = manifest['outputs'] as Map<String, dynamic>;
    final resultMap = <String, dynamic>{};

    for (var entry in outputsDef.entries) {
      final parts = (entry.value as String).split('.');
      final nodeId = parts[0];
      final outputKey = parts[1];
      
      final nodeResult = await nodeCompleters[nodeId]!.future;
      resultMap[entry.key] = nodeResult[outputKey];
    }

    return resultMap;
  }

  void _scheduleNode({
    required Map<String, dynamic> step,
    required dynamic rawInput,
    required Map<String, Completer<Map<String, dynamic>>> nodeCompleters,
  }) async {
    final String nodeId = step['id'];
    final Map<String, dynamic> inputsDef = step['inputs'];

    // 1. Kumpulkan daftar parent node yang harus ditunggu
    final List<Future> parentFutures = [];
    final Map<String, String> dependencyMap = {}; // inputName -> 'nodeId.outputKey'

    for (var entry in inputsDef.entries) {
      final String source = entry.value;
      if (source != '@input') {
        final parts = source.split('.');
        final parentId = parts[0];
        dependencyMap[entry.key] = source;
        parentFutures.add(nodeCompleters[parentId]!.future);
      }
    }

    // 2. Tunggu semua parent selesai
    await Future.wait(parentFutures);

    // 3. Kumpulkan tensor input yang sudah siap
    final Map<String, dynamic> resolvedInputs = {};
    for (var entry in inputsDef.entries) {
      final String inputName = entry.key;
      final String source = entry.value;

      if (source == '@input') {
        resolvedInputs[inputName] = rawInput;
      } else {
        final parts = source.split('.');
        final parentResult = await nodeCompleters[parts[0]]!.future;
        resolvedInputs[inputName] = parentResult[parts[1]];
      }
    }

    // 4. Eksekusi inferensi model ONNX
    final outputs = await _runInferenceWorker(step['model'], resolvedInputs);

    // 5. Beri sinyal ke child node bahwa node ini telah selesai
    nodeCompleters[nodeId]!.complete(outputs);
  }

  Future<Map<String, dynamic>> _runInferenceWorker(
    String modelName, 
    Map<String, dynamic> inputs
  ) async {
    // Dispatch ke worker pool / isolate executor
    return {};
  }
}

```

---

### 3. Kontrol Konkurensi & Alokasi Resource (Krusial untuk Android di RPi 5)

Meskipun secara grafis ada 3 atau 4 node yang bisa berjalan paralel bersamaan, perangkat keras (CPU 4-core RPi 5) tidak boleh menerima beban tak terbatas:

* **Worker Pool / Semaphore:**
* Gunakan antrean tugas dengan pembatas (*concurrency limiter*), misalnya maksimal 2 model berat berjalan bersamaan.
* Node yang statusnya "READY" masuk ke antrean *pool* alih-alih langsung memicu thread baru.


* **Manajemen Isolate Dart:**
* Buat sekumpulan *long-lived background isolates* (misalnya 2 worker isolate) sejak aplikasi menyala.
* Kirim tugas inferensi ke worker yang sedang menganggur untuk menghindari latensi pembuatan isolate baru berulang kali (*cold start*).


* **Konfigurasi ONNX Session:**
* Di dalam masing-masing worker isolate, setel `intra_op_num_threads` ke nilai rendah (1 atau 2). Jika 2 worker berjalan paralel dan masing-masing memakai 2 thread, seluruh 4 core CPU RPi 5 akan terpakai secara optimal tanpa terjadi perebutan thread (*contention*).