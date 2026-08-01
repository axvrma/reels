import { Injectable } from '@angular/core';
import { HttpClient, HttpEvent, HttpRequest } from '@angular/common/http';
import { environment } from '../../environments/environment';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class MediaApiService {
  private apiUrl = environment.apiUrl;
  
  constructor(private http: HttpClient) {}

  getSummary(): Observable<any> { 
    return this.http.get<any>(`${this.apiUrl}/summary`); 
  }
  
  getVideos(): Observable<any> { 
    return this.http.get<any>(`${this.apiUrl}/videos`); 
  }
  
  uploadVideo(formData: FormData): Observable<HttpEvent<any>> { 
    const req = new HttpRequest('POST', `${this.apiUrl}/upload`, formData, {
      reportProgress: true
    });
    return this.http.request(req);
  }
  
  deleteVideo(id: string): Observable<any> { 
    return this.http.delete(`${this.apiUrl}/videos/${id}`); 
  }
  
  getTags(): Observable<any[]> { 
    return this.http.get<any[]>(`${this.apiUrl}/tags`); 
  }
  
  createTag(tag: { name: string; color: string }): Observable<any> { 
    return this.http.post<any>(`${this.apiUrl}/tags`, tag); 
  }
  
  updateTag(id: string, tag: { name?: string; color?: string }): Observable<any> {
    return this.http.patch<any>(`${this.apiUrl}/tags/${id}`, tag);
  }

  deleteTag(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/tags/${id}`);
  }
  
  attachTag(videoId: string, tagId: string): Observable<any> { 
    return this.http.post(`${this.apiUrl}/videos/${videoId}/tags`, { tagId }); 
  }
  
  detachTag(videoId: string, tagId: string): Observable<any> { 
    return this.http.delete(`${this.apiUrl}/videos/${videoId}/tags/${tagId}`); 
  }

  getCategories(includeInactive: boolean = false): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/categories?includeInactive=${includeInactive}`);
  }

  createCategory(category: any): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/categories`, category);
  }

  updateCategory(id: string, category: any): Observable<any> {
    return this.http.patch<any>(`${this.apiUrl}/categories/${id}`, category);
  }

  deleteCategory(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/categories/${id}`);
  }

  assignTagToCategory(categoryId: string, tagId: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/categories/${categoryId}/tags`, { tagId });
  }

  removeTagFromCategory(categoryId: string, tagId: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/categories/${categoryId}/tags/${tagId}`);
  }

  updateVideoCategory(videoId: string, payload: { categoryId: string | null; removeIncompatibleTags?: boolean }): Observable<any> {
    return this.http.patch(`${this.apiUrl}/videos/${videoId}/category`, payload);
  }

  getUsers(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/users`);
  }

  updateUserStatus(userId: string, is_active: boolean): Observable<any> {
    return this.http.patch(`${this.apiUrl}/users/${userId}/status`, { is_active: is_active ? 1 : 0 });
  }

  deleteUser(userId: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/users/${userId}`);
  }

  updateUserPassword(userId: string, password: string): Observable<any> {
    return this.http.patch(`${this.apiUrl}/users/${userId}/password`, { password });
  }
}
