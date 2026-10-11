// Offline differential fixtures. Reference runtime version is recorded separately.
// Outputs UTF-16 arrays, including isolated surrogates; never UTF-8 encodings.
const units = s => Array.from({length:s.length}, (_,i) => s.charCodeAt(i));
let seed = 0x262;
const random = n => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % n; };
const alphabet = [0x61,0x62,0x20,0xe9,0x301,0xd83d,0xde00,0xd800,0xdc00,0x3a3,0];
const strings = ['', 'abc', '😀😀', '\ud83d\ude00', '\ud800x\udc00', 'é e\u0301', 'ΟΣ', 'a\0b'];
for(let i=0;i<120;i++) strings.push(String.fromCharCode(...Array.from({length:random(12)},()=>alphabet[random(alphabet.length)])));
const cases = [];
for (const input of strings) {
  for (const position of [-20,-1,0,1,2,20]) {
    const needle = strings[random(strings.length)].slice(0, 2);
    for(const op of ['indexOf','lastIndexOf','includes','startsWith','endsWith']) {
      const result = input[op](needle, position);
      cases.push({op,input:units(input),needle:units(needle),position,...(typeof result==='boolean'?{expected_bool:result}:{expected_number:result})});
    }
    for(const op of ['charCodeAt','codePointAt']) {
      const result = input[op](position);
      cases.push({op,input:units(input),position,expected_number:Number.isFinite(result)?result:null});
    }
    for(const op of ['slice','substring']) cases.push({op,input:units(input),position,end:2,expected_units:units(input[op](position,2))});
    for(const op of ['padStart','padEnd']) cases.push({op,input:units(input),needle:units('😀'),position,expected_units:units(input[op](position,'😀'))});
  }
  for(const op of ['toLowerCase','toUpperCase','toWellFormed']) cases.push({op,input:units(input),expected_units:units(input[op]())});
  for(const op of ['replace','replaceAll']) cases.push({op,input:units(input),needle:units(''),expected_units:units(input[op]('','[$&]'))});
  cases.push({op:'isWellFormed',input:units(input),expected_bool:input.isWellFormed()});
}
process.stdout.write(JSON.stringify(cases)+'\n');
