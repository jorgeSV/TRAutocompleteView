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

#import "TRAutocompleteView.h"
#import "TRAutocompleteItemsSource.h"
#import "TRAutocompletionCellFactory.h"

@interface TRAutocompleteView () <UITableViewDelegate, UITableViewDataSource>

@property(readwrite) id <TRSuggestionItem> selectedSuggestion;
@property(readwrite) NSArray *suggestions;

@end

@implementation TRAutocompleteView
{
    BOOL _visible;
    
    __weak UITextField *_queryTextField;
    __weak UIViewController *_contextController;
    __weak UIView *_viewPresenting;
    
    UITableView *_table;
    UIImageView *googleImage;
    id <TRAutocompleteItemsSource> _itemsSource;
    id <TRAutocompletionCellFactory> _cellFactory;
}

+ (TRAutocompleteView *)autocompleteViewBindedTo:(UITextField *)textField usingSource:(id <TRAutocompleteItemsSource>)itemsSource cellFactory:(id <TRAutocompletionCellFactory>)factory presentingIn:(UIViewController *)controller
{
    return [[TRAutocompleteView alloc] initWithFrame:CGRectZero textField:textField itemsSource:itemsSource cellFactory:factory controller:controller intoView:nil];
}

+ (TRAutocompleteView *)autocompleteViewBindedTo:(UITextField *)textField usingSource:(id <TRAutocompleteItemsSource>)itemsSource cellFactory:(id <TRAutocompletionCellFactory>)factory presentingIn:(UIViewController *)controller intoView:(UIView *)viewPresenting
{
    return [[TRAutocompleteView alloc] initWithFrame:CGRectZero textField:textField itemsSource:itemsSource cellFactory:factory controller:controller intoView:viewPresenting];
}

- (id)initWithFrame:(CGRect)frame textField:(UITextField *)textField itemsSource:(id <TRAutocompleteItemsSource>)itemsSource cellFactory:(id <TRAutocompletionCellFactory>)factory controller:(UIViewController *)controller intoView:(UIView *)viewPresenting
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self loadDefaults];
        
        _queryTextField = textField;
        _itemsSource = itemsSource;
        _cellFactory = factory;
        _contextController = controller;
		_viewPresenting = viewPresenting;
        
        _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _table.backgroundColor = [UIColor whiteColor];
        _table.separatorColor = self.separatorColor;
        _table.separatorStyle = self.separatorStyle;
        _table.delegate = self;
        _table.dataSource = self;
        
        googleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"powered-by-google-on-white"]];
        [googleImage setFrame:CGRectMake(self.frame.size.width - googleImage.frame.size.width,self.frame.size.height - googleImage.frame.size.height, googleImage.frame.size.width / 2.0f, googleImage.frame.size.height / 2.0f)];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryChanged:) name:UITextFieldTextDidChangeNotification object:_queryTextField];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        
        [self addSubview:_table];
        [self addSubview:googleImage];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)loadDefaults
{
    self.backgroundColor = [UIColor clearColor];
    
    _separatorColor = [UIColor lightGrayColor];
    _separatorStyle = UITableViewCellSeparatorStyleNone;
    
    _topMargin = 0;
    _cellHeight = 30.0f;
}

- (void)keyboardWasShown:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    CGFloat contextViewHeight = 0;
    CGFloat kbHeight = 0;
    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation))
    {
        contextViewHeight = _contextController ? _contextController.view.frame.size.height : _viewPresenting.frame.size.height;
        kbHeight = kbSize.height;
    }
    else if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
    {
        contextViewHeight = _contextController ? _contextController.view.frame.size.height : _viewPresenting.frame.size.height;
        kbHeight = kbSize.width;
    }
    
    CGPoint textPosition = [_queryTextField convertPoint:_queryTextField.bounds.origin toView: _viewPresenting ? _viewPresenting : _contextController.view]; //Taking in account Y position of queryTextField relatively to it's Window
    
    CGFloat calculatedY = textPosition.y + _queryTextField.frame.size.height + self.topMargin;
    CGFloat calculatedHeight = contextViewHeight - calculatedY - kbHeight;
    
    calculatedHeight += _contextController ? _contextController.tabBarController.tabBar.frame.size.height : 0; //keyboard is shown over it, need to compensate
    
    self.frame = CGRectMake(_viewPresenting ? _queryTextField.frame.origin.x + _viewPresenting.frame.origin.x : _queryTextField.frame.origin.x, _viewPresenting ? calculatedY - _viewPresenting.frame.origin.y : calculatedY, _queryTextField.frame.size.width, calculatedHeight);
    _table.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    [self removeFromSuperview];
    _visible = NO;
}

- (void)queryChanged:(id)sender
{
    if ([_queryTextField.text length] >= _itemsSource.minimumCharactersToTrigger)
    {
        [_itemsSource itemsFor:_queryTextField.text whenReady:^(NSArray *suggestions)
         {
             if (_queryTextField.text.length < _itemsSource.minimumCharactersToTrigger)
             {
                 _suggestions = nil;
                 [self refreshTable];
             }
             else
             {
                 _suggestions = suggestions;
                 [self refreshTable];
                 
                 if (_suggestions.count > 0 && !_visible)
                 {
                     [_contextController ? _contextController.view : _viewPresenting addSubview:self];
                     _visible = YES;
                 }
             }
         }];
    }
    else
    {
        _suggestions = nil;
        [self refreshTable];
    }
}



#pragma mark - UITableView Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _suggestions ? _suggestions.count : 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _cellHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"TRAutocompleteCell";
    
    id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [_cellFactory createReusableCellWithIdentifier:identifier];
    
    [cell setBackgroundColor:indexPath.row %2 == 0 ? [UIColor colorWithWhite:0.98f alpha:1.0f] : [UIColor whiteColor]];
    
    NSAssert([cell isKindOfClass:[UITableViewCell class]], @"Cell must inherit from UITableViewCell");
    NSAssert([cell conformsToProtocol:@protocol(TRAutocompletionCell)], @"Cell must conform TRAutocompletionCell");
    UITableViewCell <TRAutocompletionCell> *completionCell = (UITableViewCell <TRAutocompletionCell> *) cell;
    
    id suggestion = _suggestions[(NSUInteger) indexPath.row];
    NSAssert([suggestion conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");
    id <TRSuggestionItem> suggestionItem = (id <TRSuggestionItem>) suggestion;
    
    [completionCell updateWith:suggestionItem];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id suggestion = _suggestions[(NSUInteger) indexPath.row];
    NSAssert([suggestion conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");
    
    self.selectedSuggestion = (id <TRSuggestionItem>) suggestion;
    
    _queryTextField.text = self.selectedSuggestion.getAddress;
    [_queryTextField resignFirstResponder];
    
    if (self.didAutocompleteWith)
        self.didAutocompleteWith(self.selectedSuggestion);
}

- (void)refreshTable
{
    if (_queryTextField.isFirstResponder)
    {
        [_table reloadData];
        [_table setFrame:CGRectMake(_table.frame.origin.x, _table.frame.origin.y, _table.frame.size.width, _cellHeight * _suggestions.count)];
        [self setFrame:CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _table.frame.size.height)];
        [googleImage setFrame:CGRectMake(self.frame.size.width - googleImage.frame.size.width, self.frame.size.height - googleImage.frame.size.height, googleImage.frame.size.width, googleImage.frame.size.height)];
    }
}

@end