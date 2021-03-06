//
// Copyright (c) 2013, Taras Roshko
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// The views and conclusions contained in the software and documentation are those
// of the authors and should not be interpreted as representing official policies,
// either expressed or implied, of the FreeBSD Project.
//

#import "TRGoogleMapsAutocompleteItemsSource.h"
#import "TRStringExtensions.h"
#import "TRGoogleMapsSuggestion.h"

#define AFNETWORKING_2 1

#ifdef AFNETWORKING_2
    #import "AFHTTPSessionManager.h"
#else
    #import "AFJSONRequestOperation.h"
#endif

@interface TRGoogleMapsAutocompleteItemsSource()

@property NSString *apiKey;
@property NSString *language;
@property NSString *types;
@property (nonatomic) NSUInteger minimumCharactersToTrigger;

@property BOOL requestToReload;
@property BOOL loading;

@property int requestCount;

#ifdef AFNETWORKING_2

    @property AFHTTPSessionManager *manager;

#else

    @property AFJSONRequestOperation *operation;

#endif

@end

@implementation TRGoogleMapsAutocompleteItemsSource

- (id)initWithMinimumCharactersToTrigger:(NSUInteger)minimumCharactersToTrigger language:(NSString *)language apiKey:(NSString *)apiKey types:(NSString *)types
{
    self = [super init];
    if (self)
    {
        _minimumCharactersToTrigger = minimumCharactersToTrigger;
        _apiKey = apiKey;
        _language = language;
        _types = types;
        
        _location = kCLLocationCoordinate2DInvalid;
        _radiusMeters = -1;
        
        _requestCount = 0;
    }
    
    return self;
}

- (id)initWithMinimumCharactersToTrigger:(NSUInteger)minimumCharactersToTrigger language:(NSString *)language apiKey:(NSString *)apiKey
{
    self = [super init];
    if (self)
    {
        _minimumCharactersToTrigger = minimumCharactersToTrigger;
        _apiKey = apiKey;
        _language = language;
        
        _location = kCLLocationCoordinate2DInvalid;
        _radiusMeters = -1;
    }
    
    return self;
}

- (id)initWithMinimumCharactersToTrigger:(NSUInteger)minimumCharactersToTrigger apiKey:(NSString *)apiKey
{
    return [self initWithMinimumCharactersToTrigger:minimumCharactersToTrigger language:@"en" apiKey:apiKey];
}

- (NSUInteger)minimumCharactersToTrigger
{
    return _minimumCharactersToTrigger;
}

- (void)itemsFor:(NSString *)query whenReady:(void (^)(NSArray *))suggestionsReady
{
    @synchronized (self)
    {
        if (_loading)
        {
            _requestToReload = YES;
            return;
        }

        _loading = YES;
        [self requestSuggestionsFor:query whenReady:suggestionsReady];
    }
}

- (void)requestSuggestionsFor:(NSString *)query whenReady:(void (^)(NSArray *))suggestionsReady
{
#ifdef AFNETWORKING_2
    
    NSString *urlString = [self autocompleteUrlFor:query];
    NSLog(@"calling for suggestions %@", urlString);
    
    if(!_manager)
    {
        _manager = [AFHTTPSessionManager manager];
        _manager.requestSerializer = [AFJSONRequestSerializer serializer];
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    
    [_manager GET:urlString parameters:nil success:^(NSURLSessionDataTask *task, id responseObject)
    {
        _requestCount++;
        NSLog(@"received response: %d", _requestCount);
        //NSLog(@"received response from places: %@",responseObject);
        NSMutableArray *suggestions = [[NSMutableArray alloc] init];
        NSArray *predictions = [responseObject objectForKey:@"predictions"];
         
         for (NSDictionary *place in predictions)
         {
             TRGoogleMapsSuggestion *suggestion = [[TRGoogleMapsSuggestion alloc] initWithAddress:[place objectForKey:@"description"] withID:[place objectForKey:@"id"] andPlaceID:[place objectForKey:@"place_id"]];
             [suggestions addObject:suggestion];
         }
         
         if (suggestionsReady)
             suggestionsReady(suggestions);
         
         @synchronized (self)
         {
             _loading = NO;
             
             if (_requestToReload)
             {
                 _requestToReload = NO;
                 //[self itemsFor:query whenReady:suggestionsReady];
             }
         }
     }
     failure:^(NSURLSessionDataTask *task, NSError *error)
     {
         NSLog(@"Error while loading suggestions: %@", error);
         @synchronized (self)
         {
             _loading = NO;
         }

     }];
    
#else
    
    NSString *urlString = [self autocompleteUrlFor:query];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    _operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:urlRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
     {
         NSMutableArray *suggestions = [[NSMutableArray alloc] init];
         NSArray *predictions = [JSON objectForKey:@"predictions"];
         
         for (NSDictionary *place in predictions)
         {
             TRGoogleMapsSuggestion
             *suggestion = [[TRGoogleMapsSuggestion alloc] initWith:[place objectForKey:@"description"]];
             [suggestions addObject:suggestion];
         }
         
         if (suggestionsReady)
             suggestionsReady(suggestions);
         
         @synchronized (self)
         {
             _loading = NO;
             
             if (_requestToReload)
             {
                 _requestToReload = NO;
                 [self itemsFor:query whenReady:suggestionsReady];
             }
         }
     }
    failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json)
     {
         NSLog(@"Error while loading suggestions: %@", error);
         @synchronized (self)
         {
             _loading = NO;
         }
     }];
    
    [_operation start];
    
#endif

}

- (NSString*) autocompleteUrlFor:(NSString*)query
{
    [self cancelQuery];
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%@", [query urlEncode]];

    if(_types)
        [urlString appendFormat:@"&types=%@", _types];
    
    [urlString appendFormat:@"&language=%@", _language];
    [urlString appendFormat:@"&key=%@", _apiKey];

    if (CLLocationCoordinate2DIsValid(self.location))
    {
        [urlString appendFormat:@"&sensor=%@", @"true"];
        [urlString appendFormat:@"&location=%f,%f", self.location.latitude, self.location.longitude];
        if (self.radiusMeters > 0)
            [urlString appendFormat:@"&radius=%f", self.radiusMeters];
    }
    else
        [urlString appendFormat:@"&sensor=%@", @"false"];

    return urlString;
}

- (void) cancelQuery
{

#ifdef AFNETWORKING_2
    
    NSLog(@"Cancel Query . Remove Tasks: %lu", (unsigned long)_manager.tasks.count);
    
    //[_manager invalidateSessionCancelingTasks:YES];
    [_manager.operationQueue cancelAllOperations];

#endif
    
}

@end
