import { Directive } from '@angular/core';
import { BrnSheetClose } from '@spartan-ng/brain/sheet';

@Directive({
	standalone: true,
	selector: 'button[hlmSheetClose]',
	hostDirectives: [BrnSheetClose],
	host: { 'data-slot': 'sheet-close' },
})
export class HlmSheetClose {}
