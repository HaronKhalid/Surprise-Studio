import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/core/analytics.dart';
import 'package:surprise_studio/core/network/api_exception.dart';
import 'package:surprise_studio/features/auth/user.dart';
import 'package:surprise_studio/features/surprises/surprise.dart';

import '../support/fakes.dart';

/// A phone-sized, tall screen so nothing needs scrolling to be tapped.
Future<void> launch(WidgetTester tester, TestHarness h, {bool onboardingSeen = true}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(await h.app(onboardingSeen: onboardingSeen));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);
Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  group('signing in', () {
    testWidgets('a first-time visitor sees onboarding, which can be skipped, then the login screen', (t) async {
      final h = TestHarness(auth: FakeAuthRepository());
      await launch(t, h, onboardingSeen: false);
      expect(find.text('Make someone\'s day'), findsOneWidget);
      await tap(t, find.text('Skip'));
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('onboarding walks through three slides to "Get started"', (t) async {
      final h = TestHarness(auth: FakeAuthRepository());
      await launch(t, h, onboardingSeen: false);
      await tap(t, find.text('Next'));
      expect(find.text('Pick a style'), findsOneWidget);
      await tap(t, find.text('Next'));
      await tap(t, find.text('Get started'));
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('empty or invalid fields are explained and nothing is sent', (t) async {
      final auth = FakeAuthRepository();
      await launch(t, TestHarness(auth: auth));
      await tap(t, find.text('Log in'));
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      await t.enterText(field('Email'), 'not-an-email');
      await tap(t, find.text('Log in'));
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(auth.lastLoginEmail, isNull);
    });

    testWidgets('a good login lands on the home screen, with the email trimmed', (t) async {
      final auth = FakeAuthRepository();
      await launch(t, TestHarness(auth: auth));
      await t.enterText(field('Email'), '  sara@example.com ');
      await t.enterText(field('Password'), 'correct horse');
      await tap(t, find.text('Log in'));
      expect(auth.lastLoginEmail, 'sara@example.com');
      expect(find.text('Your surprises'), findsOneWidget);
    });

    testWidgets('a rejected login shows a friendly message and stays on the form', (t) async {
      final auth = FakeAuthRepository()..loginError = apiError('INVALID_CREDENTIALS', status: 401);
      await launch(t, TestHarness(auth: auth));
      await t.enterText(field('Email'), 'sara@example.com');
      await t.enterText(field('Password'), 'wrong');
      await tap(t, find.text('Log in'));
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('an offline start offers a retry instead of looking like a logout', (t) async {
      final auth = _FlakyRestore();
      await launch(t, TestHarness(auth: auth));
      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      auth.online = true;
      await tap(t, find.text('Try again'));
      expect(find.text('Your surprises'), findsOneWidget);
    });
  });

  group('home', () {
    testWidgets('empty state invites the first surprise', (t) async {
      await launch(t, TestHarness());
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Create a surprise'), findsOneWidget);
    });

    testWidgets('lists surprises with their state', (t) async {
      final h = TestHarness();
      h.surprises.seed(id: 'a', name: 'Ayesha', status: SurpriseStatus.published, slug: 'abc123XYZ_');
      h.surprises.seed(id: 'b', name: 'Hamza');
      await launch(t, h);
      expect(find.text('Ayesha'), findsOneWidget);
      expect(find.textContaining('Published'), findsOneWidget);
      expect(find.text('Hamza'), findsOneWidget);
      expect(find.textContaining('Draft'), findsOneWidget);
      expect(find.text('Create surprise'), findsOneWidget); // the floating button, once there is something
    });

    testWidgets('a failed load shows a retry that works', (t) async {
      final h = TestHarness();
      h.surprises.seed(name: 'Ayesha');
      h.surprises.failNext = const ApiException.network();
      await launch(t, h);
      expect(find.textContaining('No connection'), findsOneWidget);
      await tap(t, find.text('Try again'));
      expect(find.text('Ayesha'), findsOneWidget);
    });
  });

  group('creating a surprise end to end', () {
    Future<void> openWizard(WidgetTester t, TestHarness h) async {
      await launch(t, h);
      await tap(t, find.text('Create a surprise'));
    }

    testWidgets('the name is required before continuing', (t) async {
      final h = TestHarness();
      await openWizard(t, h);
      expect(find.text('Who is this surprise for?'), findsOneWidget);
      await tap(t, find.text('Continue'));
      expect(find.text('Enter their name'), findsOneWidget);
      expect(h.surprises.calls, isNot(contains('create')));
    });

    testWidgets('who, words, photos, style, publish, share', (t) async {
      final h = TestHarness();
      h.picker.next = [image('a.jpg'), image('b.jpg')];
      await openWizard(t, h);

      // 1. who
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Best friend'));
      await tap(t, find.text('Continue'));
      expect(h.surprises.calls, contains('create'));

      // 2. words
      expect(find.text('What do you want to say?'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Your message'), 'Happy birthday, Sara!');
      await tap(t, find.text('Continue'));

      // 3. photos
      expect(find.text('Add your favourite photos'), findsOneWidget);
      await tap(t, find.textContaining('Add photos'));
      await t.pumpAndSettle();
      expect(find.text('Photo 1'), findsOneWidget);
      expect(find.text('Photo 2'), findsOneWidget);
      await tap(t, find.text('Continue'));

      // 4. style: continue is disabled until one is chosen
      expect(find.text('Pick a style'), findsOneWidget);
      final continueButton = find.widgetWithText(FilledButton, 'Continue');
      expect(t.widget<FilledButton>(continueButton).onPressed, isNull);
      await tap(t, find.text('Cinematic'));
      expect(t.widget<FilledButton>(continueButton).onPressed, isNotNull);
      expect(find.text('Accent colour'), findsOneWidget);
      await tap(t, continueButton);

      // 5. review + publish
      expect(find.text('Almost there'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4)); // name, style, photo, message
      await tap(t, find.text('Publish'));

      // published
      expect(find.text('Your surprise is ready!'), findsOneWidget);
      expect(find.text('http://localhost:3000/s/abc123XYZ_'), findsOneWidget);
      await tap(t, find.text('Share'));
      expect(h.sharer.shared.single, contains('http://localhost:3000/s/abc123XYZ_'));
      await tap(t, find.text('Copy link'));
      expect(h.sharer.copied.single, 'http://localhost:3000/s/abc123XYZ_');
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing); // nothing floats over the Done button

      expect(h.analytics.events, containsAll([AppEvent.createStarted, AppEvent.surpriseCreated, AppEvent.photoUploaded, AppEvent.templateSelected, AppEvent.surprisePublished, AppEvent.shareClicked]));

      // Done returns to a list that shows it as published
      await tap(t, find.text('Done'));
      expect(find.text('Your surprises'), findsOneWidget);
      expect(find.textContaining('Published'), findsOneWidget);
    });

    testWidgets('publishing is blocked until requirements are met, and "Fix" jumps to the right step', (t) async {
      final h = TestHarness();
      await openWizard(t, h);
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Continue'));
      await tap(t, find.text('Continue')); // skip the message
      await tap(t, find.text('Continue')); // skip the photos
      await tap(t, find.text('Cinematic'));
      await tap(t, find.text('Continue'));

      expect(find.text('A couple of things are still missing.'), findsOneWidget);
      expect(find.text('At least 1 photo'), findsOneWidget);
      expect(find.text('A message'), findsOneWidget);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish')).onPressed, isNull);

      await tap(t, find.text('Fix').first); // the photo is listed first
      expect(find.text('Add your favourite photos'), findsOneWidget);
    });

    testWidgets('a server-side publish rejection is shown in plain words', (t) async {
      final h = TestHarness();
      h.picker.next = [image('a.jpg')];
      await openWizard(t, h);
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Continue'));
      await t.enterText(find.widgetWithText(TextField, 'Your message'), 'Hi');
      await tap(t, find.text('Continue'));
      await tap(t, find.textContaining('Add photos'));
      await tap(t, find.text('Continue'));
      await tap(t, find.text('Cinematic'));
      await tap(t, find.text('Continue'));

      h.surprises.failNext = apiError('PHOTOS_REQUIRED', message: 'Add at least 2 photos before publishing');
      await tap(t, find.text('Publish'));
      expect(find.text('Add at least 2 photos before publishing'), findsOneWidget);
      expect(find.text('Almost there'), findsOneWidget); // still here, can fix and retry
    });

    testWidgets('a failed photo upload is explained and can be dismissed without blocking the rest', (t) async {
      final h = TestHarness();
      h.surprises.uploadError = apiError('INVALID_FILE_TYPE');
      h.picker.next = [image('a.jpg'), image('bad.jpg')];
      await openWizard(t, h);
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Continue'));
      await tap(t, find.text('Continue'));
      await tap(t, find.textContaining('Add photos'));
      expect(find.text('Photo 1'), findsOneWidget);
      expect(find.text('Only JPEG, PNG and WebP photos are supported.'), findsOneWidget);
      await tap(t, find.byTooltip('Dismiss'));
      expect(find.text('Only JPEG, PNG and WebP photos are supported.'), findsNothing);
    });

    testWidgets('the picker is only offered the room that is left under the 10 photo limit', (t) async {
      final h = TestHarness();
      h.picker.next = [for (var i = 0; i < 4; i++) image('p$i.jpg')];
      await openWizard(t, h);
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Continue'));
      await tap(t, find.text('Continue'));
      await tap(t, find.textContaining('Add photos'));
      expect(h.picker.lastLimit, 10);
      await tap(t, find.textContaining('Add photos'));
      expect(h.picker.lastLimit, 6);
    });

    testWidgets('memories can be added and removed', (t) async {
      final h = TestHarness();
      await openWizard(t, h);
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Continue'));
      await tap(t, find.text('Add a memory'));
      await t.enterText(find.widgetWithText(TextField, 'The memory'), 'The road trip');
      await t.pump();
      await tap(t, find.text('Add'));
      expect(find.text('The road trip'), findsOneWidget);
      await tap(t, find.byTooltip('Remove memory'));
      expect(find.text('The road trip'), findsNothing);
    });

    testWidgets('closing the wizard keeps the draft on the server and in the list', (t) async {
      final h = TestHarness();
      await openWizard(t, h);
      await t.enterText(field('Their name'), 'Sara');
      await tap(t, find.text('Continue'));
      await tap(t, find.byTooltip('Back'));
      await tap(t, find.byTooltip('Close'));
      expect(find.text('Your surprises'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
    });
  });

  group('an existing surprise', () {
    testWidgets('published: shows the link; copy and share work; unpublish and delete confirm', (t) async {
      final h = TestHarness();
      h.surprises.seed(id: 'a', name: 'Ayesha', status: SurpriseStatus.published, slug: 'abc123XYZ_', templateId: 't-cinematic', message: 'Hello there');
      await launch(t, h);
      await tap(t, find.text('Ayesha'));
      expect(find.text('http://localhost:3000/s/abc123XYZ_'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);

      await tap(t, find.text('Copy'));
      expect(h.sharer.copied.single, 'http://localhost:3000/s/abc123XYZ_');
      await tap(t, find.text('Share'));
      expect(h.sharer.shared.single, contains('abc123XYZ_'));

      await tap(t, find.text('Unpublish'));
      expect(h.surprises.calls, contains('unpublish:a'));

      await tap(t, find.text('Delete surprise'));
      expect(find.textContaining('permanently deleted'), findsOneWidget);
      await tap(t, find.text('Cancel'));
      expect(h.surprises.calls, isNot(contains('delete:a')));
      await tap(t, find.text('Delete surprise'));
      await tap(t, find.text('Delete'));
      expect(h.surprises.calls, contains('delete:a'));
      expect(find.text('Your surprises'), findsOneWidget);
    });

    testWidgets('a draft with no style cannot be previewed', (t) async {
      final h = TestHarness();
      h.surprises.seed(id: 'a', name: 'Hamza');
      await launch(t, h);
      await tap(t, find.text('Hamza'));
      expect(find.text('Pick a style to preview'), findsOneWidget);
      expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Pick a style to preview')).onPressed, isNull);
    });

    testWidgets('editing reopens the wizard with the saved details', (t) async {
      final h = TestHarness();
      h.surprises.seed(id: 'a', name: 'Hamza', message: 'Old message');
      await launch(t, h);
      await tap(t, find.text('Hamza'));
      await tap(t, find.text('Edit'));
      expect(find.widgetWithText(TextFormField, 'Hamza'), findsOneWidget);
      await tap(t, find.text('Continue'));
      expect(find.text('Old message'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('log out returns to the login screen', (t) async {
      final h = TestHarness();
      await launch(t, h);
      await tap(t, find.byTooltip('Settings'));
      expect(find.text('sara@example.com'), findsOneWidget);
      await tap(t, find.text('Log out'));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(h.auth.user, isNull);
    });

    testWidgets('deleting the account needs the password, then signs out', (t) async {
      final h = TestHarness();
      await launch(t, h);
      await tap(t, find.byTooltip('Settings'));
      await tap(t, find.text('Delete account'));
      final confirm = find.widgetWithText(TextButton, 'Delete everything');
      expect(t.widget<TextButton>(confirm).onPressed, isNull); // disabled until a password is typed
      await t.enterText(find.byType(TextField), 'my-password');
      await t.pump();
      await tap(t, confirm);
      expect(h.auth.deleted, isTrue);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('cancelling the delete dialog deletes nothing', (t) async {
      final h = TestHarness();
      await launch(t, h);
      await tap(t, find.byTooltip('Settings'));
      await tap(t, find.text('Delete account'));
      await tap(t, find.text('Cancel'));
      expect(h.auth.deleted, isFalse);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}

// ---- helpers local to this file ----

/// Restores a session only once "online".
class _FlakyRestore extends FakeAuthRepository {
  _FlakyRestore() : super(user: const User(id: 'u1', email: 'sara@example.com'));
  bool online = false;

  @override
  Future<User?> restore() async {
    if (!online) throw const ApiException.network();
    return super.restore();
  }
}
