import 'dart:async';

class OnErrorResumeNextStreamTransformer<T> implements StreamTransformer<T, T> {
  final StreamTransformer<T, T> transformer;

  OnErrorResumeNextStreamTransformer(Stream<T> recoveryStream)
      : transformer = _buildTransformer(recoveryStream);

  @override
  Stream<T> bind(Stream<T> stream) => transformer.bind(stream);

  static StreamTransformer<T, T> _buildTransformer<T>(
      Stream<T> recoveryStream) {
    StreamController<T> controller;
    bool shouldCloseController = true;

    void safeClose() {
      if (shouldCloseController) {
        controller.close();
      }
    }

    return new StreamTransformer<T, T>((Stream<T> input, bool cancelOnError) {
      StreamSubscription<T> inputSubscription;
      StreamSubscription<T> recoverySubscription;

      controller = new StreamController<T>(
          sync: true,
          onListen: () {
            inputSubscription = input.listen((T data) {
              controller.add(data);
            }, onError: (dynamic e, dynamic s) {
              shouldCloseController = false;

              recoverySubscription = recoveryStream.listen(controller.add,
                  onError: controller.addError,
                  onDone: controller.close,
                  cancelOnError: cancelOnError);

              inputSubscription.cancel();
            }, onDone: safeClose, cancelOnError: cancelOnError);
          },
          onPause: ([Future<dynamic> resumeSignal]) {
            inputSubscription?.pause(resumeSignal);
            recoverySubscription?.pause(resumeSignal);
          },
          onResume: () {
            inputSubscription?.resume();
            recoverySubscription?.resume();
          },
          onCancel: () {
            return Future.wait(<Future<dynamic>>[
              inputSubscription?.cancel(),
              recoverySubscription?.cancel()
            ].where((Future<dynamic> future) => future != null));
          });

      return controller.stream.listen(null);
    });
  }
}
