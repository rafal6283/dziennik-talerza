import 'package:dziennik_talerza/fodmap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rozpoznawanie grup', () {
    expect(groupsInText('Kanapka z chlebem pszennym i cebulą'), contains('fruktany'));
    expect(groupsInText('Jogurt naturalny'), {'laktoza'});
    expect(groupsInText('Mleko bez laktozy'), isEmpty);
    expect(groupsInText('Bigos'), {'kapustne'});
    expect(groupsInText('Hummus z ciecierzycy'), {'gos'});
    expect(groupsInText('Woda gazowana'), {'gazowane'});
    expect(groupsInText('Porcja ryżu'), isEmpty); // „por” tylko jako osobne słowo
  });

  test('plan diety: fazy i zakazane grupy', () {
    final e = Elimination(id: 'e', person: 'me', groups: ['laktoza', 'fruktany'], start: '2026-11-01', elimDays: 14);
    expect(e.elimEnd, '2026-11-14');
    expect(e.testOf(0), ('2026-11-15', '2026-11-17', '2026-11-19'));
    expect(e.testOf(1), ('2026-11-20', '2026-11-22', '2026-11-24'));
    expect(e.end, '2026-11-24');
    expect(e.forbiddenOn('2026-11-05'), {'laktoza', 'fruktany'});
    expect(e.forbiddenOn('2026-11-16'), {'fruktany'});
    expect(e.forbiddenOn('2026-11-18'), {'laktoza', 'fruktany'});
    expect(e.forbiddenOn('2026-11-21'), {'laktoza'});
    expect(e.forbiddenOn('2026-11-25'), isEmpty);
    expect(e.phaseOn('2026-11-05').stage, ElimStage.elimination);
    expect(e.phaseOn('2026-11-05').day, 5);
    expect(e.phaseOn('2026-11-21').group, 'fruktany');
    expect(e.phaseOn('2026-11-19').stage, ElimStage.wash);
    final j = Elimination.fromJson(e.toJson());
    expect(j.groups, ['laktoza', 'fruktany']);
    expect((j.start, j.elimDays), ('2026-11-01', 14));
  });
}
