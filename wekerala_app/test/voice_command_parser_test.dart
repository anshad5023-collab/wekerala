import 'package:flutter_test/flutter_test.dart';
import 'package:wekerala/features/orders/voice_command_parser.dart';

void main() {
  group('parseVoiceOrder — Malayalam script', () {
    test('quantity + unit + item', () {
      final items = parseVoiceOrder('രണ്ട് കിലോ അരി');
      expect(items.length, 1);
      expect(items.first.qty, 2);
      expect(items.first.unit, 'kg');
      expect(items.first.name, 'അരി');
    });

    test('fraction quantity (അര = 0.5)', () {
      final items = parseVoiceOrder('അര കിലോ പഞ്ചസാര');
      expect(items.first.qty, 0.5);
      expect(items.first.unit, 'kg');
      expect(items.first.name, 'പഞ്ചസാര');
    });

    test('multiple items in one utterance', () {
      final items = parseVoiceOrder('രണ്ട് കിലോ അരി മൂന്ന് സോപ്പ്');
      expect(items.length, 2);
      expect(items[0].qty, 2);
      expect(items[0].unit, 'kg');
      expect(items[1].qty, 3);
      expect(items[1].unit, 'piece');
      expect(items[1].name, 'സോപ്പ്');
    });

    test('no quantity defaults to 1 piece', () {
      final items = parseVoiceOrder('സോപ്പ്');
      expect(items.first.qty, 1);
      expect(items.first.unit, 'piece');
    });
  });

  group('parseVoiceOrder — Manglish', () {
    test('randu kilo ari', () {
      final items = parseVoiceOrder('randu kilo ari');
      expect(items.first.qty, 2);
      expect(items.first.unit, 'kg');
      expect(items.first.name, 'ari');
    });

    test('oru litre paal (1 litre milk)', () {
      final items = parseVoiceOrder('oru litre paal');
      expect(items.first.qty, 1);
      expect(items.first.unit, 'litre');
      expect(items.first.name, 'paal');
    });
  });

  group('parseVoiceOrder — English + digits', () {
    test('2 kg rice, 1 sugar', () {
      final items = parseVoiceOrder('2 kg rice, 1 sugar');
      expect(items.length, 2);
      expect(items[0].qty, 2);
      expect(items[0].unit, 'kg');
      expect(items[0].name, 'rice');
      expect(items[1].qty, 1);
      expect(items[1].unit, 'piece');
    });

    test('decimal quantity', () {
      final items = parseVoiceOrder('1.5 kg onion');
      expect(items.first.qty, 1.5);
      expect(items.first.unit, 'kg');
    });
  });

  group('parseVoiceOrder — robustness', () {
    test('empty input yields no items', () {
      expect(parseVoiceOrder(''), isEmpty);
      expect(parseVoiceOrder('   '), isEmpty);
    });

    test('filler words are dropped from names', () {
      final items = parseVoiceOrder('രണ്ട് കിലോ അരി ഉം ഒരു സോപ്പ്');
      expect(items.length, 2);
      expect(items[0].name, 'അരി');
      expect(items[1].name, 'സോപ്പ്');
    });

    test('Malayalam-script digits are understood', () {
      final items = parseVoiceOrder('൩ കിലോ അരി');
      expect(items.first.qty, 3);
      expect(items.first.unit, 'kg');
    });
  });
}
