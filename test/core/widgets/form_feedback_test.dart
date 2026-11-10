import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/core/widgets/form_feedback.dart';

void main() {
  testWidgets('a wrong form scrolls to the top wrong field and reads it once', (tester) async {
    final form = GlobalKey<FormState>();
    final first = TextEditingController();
    final second = TextEditingController();
    final scroll = ScrollController();
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          ctx = context;
          return Form(
            key: form,
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(children: [
                TextFormField(controller: first, validator: (v) => v!.isEmpty ? 'Enter your first name' : null),
                const SizedBox(height: 1200),
                TextFormField(controller: second, validator: (v) => v!.isEmpty ? 'Enter your email' : null),
              ]),
            ),
          );
        }),
      ),
    ));

    // Start scrolled to the bottom, like a user who pressed Save there.
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();

    expect(validateForm(ctx, form), isFalse);
    await tester.pumpAndSettle();
    expect(scroll.offset, lessThan(100), reason: 'scrolled up to the first name field');
    expect(tester.takeAnnouncements().map((a) => a.message), ['Enter your first name']);

    first.text = 'Asha';
    second.text = 'asha@example.com';
    expect(validateForm(ctx, form), isTrue);
    expect(tester.takeAnnouncements(), isEmpty);
  });
}
