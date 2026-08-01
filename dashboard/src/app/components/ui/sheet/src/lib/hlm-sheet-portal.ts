import { Directive } from '@angular/core';
import { BrnSheetContent } from '@spartan-ng/brain/sheet';

@Directive({
	standalone: true,
	selector: '[hlmSheetPortal]',
	hostDirectives: [{ directive: BrnSheetContent, inputs: ['context', 'class'] }],
})
export class HlmSheetPortal {}
