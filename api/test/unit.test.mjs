import test from 'node:test';
import assert from 'node:assert/strict';
import { toCsv } from '../src/csv.mjs';
import { cleanText, cleanInt, cleanDate, oneOf, cleanIds, HttpError } from '../src/validate.mjs';

test('csv quotes commas, quotes and line breaks and keeps blanks', () => {
  const out = toCsv(['a', 'b'], [{ a: 'x,y', b: 'say "hi"' }, { a: 'line\nbreak', b: null }]);
  assert.equal(out, '﻿a,b\r\n"x,y","say ""hi"""\r\n"line\nbreak",\r\n');
});
test('text is trimmed, blank becomes null, required and length enforced', () => {
  assert.equal(cleanText('  hi ', 5, 'x'), 'hi');
  assert.equal(cleanText('  ', 5, 'x'), null);
  assert.throws(() => cleanText('', 5, 'x', true), HttpError);
  assert.throws(() => cleanText('abcdef', 5, 'x'), HttpError);
});
test('ids must be positive whole numbers', () => {
  assert.equal(cleanInt('7', 'x'), 7);
  assert.equal(cleanInt(null, 'x'), null);
  assert.throws(() => cleanInt('1 OR 1=1', 'x'), HttpError);
  assert.throws(() => cleanInt(-1, 'x'), HttpError);
  assert.throws(() => cleanInt(null, 'x', true), HttpError);
});
test('dates must be real calendar dates', () => {
  assert.equal(cleanDate('2026-02-28', 'x'), '2026-02-28');
  assert.equal(cleanDate('', 'x'), null);
  assert.throws(() => cleanDate('2026-02-30', 'x'), HttpError);
  assert.throws(() => cleanDate('28/02/2026', 'x'), HttpError);
});
test('allowed values and id lists', () => {
  assert.equal(oneOf('Open', ['Open'], 'x'), 'Open');
  assert.throws(() => oneOf('DROP', ['Open'], 'x'), HttpError);
  assert.deepEqual(cleanIds([1, '1', 2]), [1, 2]);
  assert.deepEqual(cleanIds(undefined), []);
  assert.throws(() => cleanIds('1'), HttpError);
});
