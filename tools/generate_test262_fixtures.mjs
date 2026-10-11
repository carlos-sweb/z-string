// Execute only the pinned, locally vendored selection to extract typed assertions.
// Original expected values come from Test262; the harness validates them in Node.
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const base = new URL('../tests/spec/data/test262/', import.meta.url);
const files = ['at-returns-code-unit.js','at-returns-item-relative-index.js','toWellFormed-returns-well-formed-string.js','padStart-normal-operation.js','codePointAt-return-utf16-decode.js','toLowerCase-Final_Sigma_U180E.js','toLowerCase-special_casing_conditional.js','normalize-form-is-not-valid-throws.js'];
const units = s => Array.from({length:s.length}, (_,i)=>s.charCodeAt(i));
const cases = [];
for (const source of files) {
  let pending;
  const context = vm.createContext({
    __record(op,input,args) {
      pending={source,op,input:units(input)};
      if(op==='at'||op==='codePointAt') pending.position=args[0]??0;
      if(op==='padStart') { pending.position=args[0]; pending.needle=units(String(args[1])); }
      if(op==='normalize') { pending.op='normalize_error'; pending.form=String(args[0]); }
    },
    assert: {
      sameValue(actual, expected) {
        if(!Object.is(actual,expected)) throw new Error(`${source}: reference assertion failed`);
        if(!pending) return; // typeof-method checks are not string algorithms.
        if(typeof expected==='string') pending.expected_units=units(expected);
        else if(typeof expected==='number') pending.expected_number=expected;
        else throw new Error('Unmapped assertion');
        cases.push(pending); pending=undefined;
      },
      throws(errorType, callback) {
        let error;
        try {callback();} catch(e) {error=e;}
        if(!error||error.name!==errorType.name) throw new Error(`${source}: reference throw assertion failed`);
        if(pending?.op!=='normalize_error') throw new Error('Unmapped throw');
        cases.push(pending); pending=undefined;
      }
    }
  });
  vm.runInContext(`for(const name of ['at','codePointAt','padStart','toLowerCase','toWellFormed','normalize']) {
    const original=String.prototype[name];
    String.prototype[name]=function(...args) { __record(name,String(this),args); return original.apply(this,args); };
  }`,context);
  vm.runInContext(readFileSync(new URL(source,base),'utf8'),context,{filename:fileURLToPath(new URL(source,base)),timeout:1000});
}
process.stdout.write(JSON.stringify(cases)+'\n');
