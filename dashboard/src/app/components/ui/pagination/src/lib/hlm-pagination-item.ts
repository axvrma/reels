import { Directive } from '@angular/core';

@Directive({
	standalone: true,
	selector: 'li[hlmPaginationItem]',
	host: { 'data-slot': 'pagination-item' },
})
export class HlmPaginationItem {}
