import {BaseCompiler} from '../base-compiler.js';

export class BashCompiler extends BaseCompiler {
    static get key() {
        return 'bash';
    }
}