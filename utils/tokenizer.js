const { exp, or, sat, many, setValue, valueOf } = require('./parserMonad.js');

const reg = (r, name) => sat(c => r.test(c), name);
const char = c => sat(v => v == c, `'%{c}'`);
const space = reg(/\s/, 'space');
const normal = reg(/[^\(\)\s\']/, 'normal char')

const leadingSpace = p => exp(function*() {
  yield many(space);
  return p;
});

const closeBracket = leadingSpace(exp(function*() {
  yield char(')');
  return setValue({type: 'CloseBracket'})
}));
const openBracket = leadingSpace(exp(function*() {
  yield char('(');
  return setValue({type: 'OpenBracket'})
}));
const quote = leadingSpace(exp(function*() {
  yield char("'");
  return setValue({type: 'Quote'})
}));

const isNum = token => !isNaN(Number(token));

const isBool = token => token === "true" || token === "false";

const token = leadingSpace(exp(function*() {
  const c = yield normal;
  const cs = yield many(normal);
  const value = [c, ...cs].join('');
  if(isNum(value))
    return setValue({type: 'NumberToken', value: Number(value)});
  if(isBool(value))
    return setValue({type: 'BoolToken', value: value === 'true'});
  return setValue({type: 'BasicToken', value});
}));

const expression = many(or(closeBracket, openBracket, quote, token));

module.exports = function(text) {
  const result = expression(text);
  return valueOf(result, text);
}
