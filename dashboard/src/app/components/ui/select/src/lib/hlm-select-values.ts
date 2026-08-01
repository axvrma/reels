import { Directive } from '@angular/core';
import { BrnSelectValues } from '@spartan-ng/brain/select';

@Directive({
	standalone: true, selector: '[hlmSelectValues]', hostDirectives: [BrnSelectValues] })
export class HlmSelectValues {}
