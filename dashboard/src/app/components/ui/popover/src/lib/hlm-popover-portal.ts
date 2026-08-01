import { Directive } from '@angular/core';
import { BrnPopoverContent } from '@spartan-ng/brain/popover';

@Directive({
	standalone: true,
	selector: '[hlmPopoverPortal]',
	hostDirectives: [{ directive: BrnPopoverContent, inputs: ['context', 'class'] }],
})
export class HlmPopoverPortal {}
