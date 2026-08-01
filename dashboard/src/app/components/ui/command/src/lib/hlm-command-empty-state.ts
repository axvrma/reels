import { Directive } from '@angular/core';
import { BrnCommandEmpty } from '@spartan-ng/brain/command';

@Directive({
	standalone: true,
	selector: '[hlmCommandEmptyState]',
	hostDirectives: [BrnCommandEmpty],
})
export class HlmCommandEmptyState {}
