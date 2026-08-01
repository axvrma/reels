import { Directive } from '@angular/core';
import { BrnPopover } from '@spartan-ng/brain/popover';

@Directive({
	standalone: true,
	selector: '[hlmPopover],hlm-popover',
	hostDirectives: [
		{
			directive: BrnPopover,
			inputs: ['align', 'attachTo', 'autoFocus', 'closeOnOutsidePointerEvents', 'offsetX', 'sideOffset', 'state'],
			outputs: ['stateChanged', 'closed'],
		},
	],
	host: { 'data-slot': 'popover' },
})
export class HlmPopover {}
