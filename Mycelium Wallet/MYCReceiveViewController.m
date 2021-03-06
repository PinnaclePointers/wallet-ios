//
//  MYCReceiveViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCReceiveViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCTextFieldLiveFormatter.h"
#import "MYCCurrencyFormatter.h"
#import "MYCCurrenciesViewController.h"
#import "MYCBackupViewController.h"

@interface MYCReceiveViewController ()

@property(nonatomic,readonly) MYCWallet* wallet;
@property(nonatomic) MYCWalletAccount* account;
@property(nonatomic) BTCAmount requestedAmount;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *borderHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *QRCodeProportionalHeightConstraint;

@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UIButton *shareButton;

@property (weak, nonatomic) IBOutlet UIButton *currencyButton;
@property (weak, nonatomic) IBOutlet UITextField *amountField;
@property (nonatomic) MYCTextFieldLiveFormatter* liveFormatter;


@property (weak, nonatomic) IBOutlet UIImageView *qrcodeView;
@property (weak, nonatomic) IBOutlet UIButton* accountButton;
@property (weak, nonatomic) IBOutlet UILabel* addressLabel;

@property (weak, nonatomic) IBOutlet UIView *editingOverlay;

@property (weak, nonatomic) IBOutlet UIView *backupWarningOverlay;


@property(nonatomic) NSNumber* previousBrightness;

@end

@implementation MYCReceiveViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Receive Bitcoins", @"");
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currencyDidUpdate:) name:MYCWalletCurrencyDidUpdateNotification object:nil];

    self.borderHeightConstraint.constant = 1.0/[UIScreen mainScreen].nativeScale;

    [self reloadAccount];
    [self updateCurrency];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self restoreBrightness];
    [self updateCurrency];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.amountField becomeFirstResponder];

    [[MYCWallet currentWallet] updateExchangeRate:YES completion:^(BOOL success, NSError *error) {
        if (!success && error)
        {
            MYCError(@"MYCReceiveViewController: Automatic update of exchange rate failed: %@", error);
        }
    }];

    [self warnAboutBackupIfNeeded];
}

- (void) warnAboutBackupIfNeeded {

    if ([MYCWallet currentWallet].isBackedUp) return;

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Back up your wallet", @"")
                                                                   message:NSLocalizedString(@"Any software of hardware failure may render your funds forever inaccessible.", @"")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self backup:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)dealloc
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [notificationCenter removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}


- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

- (void) currencyDidUpdate:(NSNotification*)notif {
    [self updateCurrency];
}

- (void) updateCurrency {
    self.amountField.placeholder = [MYCWallet currentWallet].primaryCurrencyFormatter.placeholderText;
    BTCAmount amountToPay = self.requestedAmount;
    if (amountToPay > 0) {
        self.amountField.text = [[MYCWallet currentWallet].primaryCurrencyFormatter.nakedFormatter stringFromNumber:@(amountToPay)];
    } else {
        self.amountField.text = @"";
    }

    self.liveFormatter.textField = nil;
    self.liveFormatter = [[MYCTextFieldLiveFormatter alloc] initWithTextField:self.amountField numberFormatter:[MYCWallet currentWallet].primaryCurrencyFormatter.nakedFormatter];

    [self.currencyButton setTitle:self.wallet.primaryCurrencyFormatter.currencyCode forState:UIControlStateNormal];

    self.amountField.placeholder = self.wallet.primaryCurrencyFormatter.placeholderText;
}

- (void) reloadAccount
{
    [self.wallet inDatabase:^(FMDatabase *db) {
        self.account = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
    }];
}

- (void) setAccount:(MYCWalletAccount *)account
{
    _account = account;
    [self updateAllViews];
}

- (void) setRequestedAmount:(BTCAmount)requestedAmount
{
    MYCLog(@"Set Requested Amount: %@ btc", @(((double)requestedAmount)/BTCCoin));
    _requestedAmount = requestedAmount;
    [self updateAllViews];
}

- (void) updateAllViews
{
    if (!self.isViewLoaded) return;

    if (![MYCWallet currentWallet].isBackedUp) {
        self.backupWarningOverlay.hidden = (self.requestedAmount < 0.1 * BTCCoin);
    }

    [self.accountButton setTitle:self.account.label ?: @"?" forState:UIControlStateNormal];

    NSString* address = self.account.externalAddress.base58String;
    self.addressLabel.text = address;

    NSString* qrString = address;

    if (self.requestedAmount > 0)
    {
        NSURL* url = [BTCBitcoinURL URLWithAddress:self.account.externalAddress amount:self.requestedAmount label:nil];
        qrString = [url absoluteString];
    }

    self.qrcodeView.image = [BTCQRCode imageForString:qrString
                                                 size:self.qrcodeView.bounds.size
                                                scale:[UIScreen mainScreen].scale];
}


- (IBAction)close:(id)sender
{
    [self setEditing:NO animated:YES];
    if (self.completionBlock) self.completionBlock();
    self.completionBlock = nil;
}

- (IBAction)share:(id)sender
{
    [self setEditing:NO animated:YES];

    NSArray* items;
    
    if (self.requestedAmount > 0)
    {
        NSString* amount = [self.wallet.primaryCurrencyFormatter stringFromAmount:self.requestedAmount];
        items = @[[NSString stringWithFormat:NSLocalizedString(@"Please send me %@ to %@", @""), amount, self.account.externalAddress.base58String]];
    }
    else
    {
        items = @[self.account.externalAddress.base58String];
    }

    UIActivityViewController* activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityController.excludedActivityTypes = @[];
    [self presentViewController:activityController animated:YES completion:nil];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
    BOOL wasEditing = self.editing;

    [super setEditing:editing animated:animated];

    if (wasEditing == editing) return;

    if (self.isEditing)
    {
        if (!self.amountField.isFirstResponder)
        {
            [self.amountField becomeFirstResponder];
        }
        if (animated)
        {
            self.editingOverlay.hidden = NO;
            self.editingOverlay.alpha = 0.0;
            [UIView animateWithDuration:0.5 animations:^{
                self.editingOverlay.alpha = 1.0;
            } completion:^(BOOL finished) {
            }];
        }
        else
        {
            self.editingOverlay.hidden = NO;
            self.editingOverlay.alpha = 1.0;
        }
    }
    else
    {
        [self.amountField resignFirstResponder];

        if (animated)
        {
            [UIView animateWithDuration:0.25 animations:^{
                self.editingOverlay.alpha = 0.0;
            } completion:^(BOOL finished) {
                self.editingOverlay.alpha = 1.0;
                self.editingOverlay.hidden = YES;
            }];
        }
        else
        {
            self.editingOverlay.hidden = YES;
        }
    }
}

- (IBAction)editingOverlayTap:(id)sender
{
    [self setEditing:NO animated:YES];
}

- (IBAction)tapAddress:(UILongPressGestureRecognizer*)gr
{
    if (gr.state == UIGestureRecognizerStateBegan)
    {
        [self becomeFirstResponder];
        UIMenuController* menu = [UIMenuController sharedMenuController];
        [menu setTargetRect:CGRectInset(self.addressLabel.bounds, 0, self.addressLabel.bounds.size.height/3.0) inView:self.addressLabel];
        [menu setMenuVisible:YES animated:YES];
    }
}

- (IBAction)tapQRCode:(id)sender
{
    if (!self.previousBrightness)
    {
        self.previousBrightness = @([UIScreen mainScreen].brightness);
    }

    // If too low, restore brightness.
    if (([UIScreen mainScreen].brightness / self.previousBrightness.doubleValue) <= 0.251)
    {
        [UIScreen mainScreen].brightness = self.previousBrightness.doubleValue;
        self.previousBrightness = nil;
    }
    else
    {
        [UIScreen mainScreen].brightness = 0.5 * [UIScreen mainScreen].brightness;
    }
}

- (void) restoreBrightness
{
    if (self.previousBrightness)
    {
        [UIScreen mainScreen].brightness = self.previousBrightness.doubleValue;
        self.previousBrightness = nil;
    }
}

- (BOOL)canBecomeFirstResponder
{
    // To support UIMenuController.
    return YES;
}

- (void) copy:(id)_
{
    [[UIPasteboard generalPasteboard] setValue:self.addressLabel.text
                             forPasteboardType:(id)kUTTypeUTF8PlainText];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(copy:))
    {
        return YES;
    }
    return NO;
}

- (IBAction)openCurrencyPicker:(id)sender
{
    [self restoreBrightness];
    MYCCurrenciesViewController* currenciesVC = [[MYCCurrenciesViewController alloc] initWithNibName:nil bundle:nil];
    currenciesVC.amount = self.requestedAmount;
    UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:currenciesVC];
    [self presentViewController:navC animated:YES completion:nil];
}

- (IBAction)didBeginEditingBtc:(id)sender
{
    [self setEditing:YES animated:YES];
    [self restoreBrightness];
}

- (IBAction)didEditBtc:(id)sender
{
    self.requestedAmount = BTCAmountFromDecimalNumber([self.wallet.primaryCurrencyFormatter.nakedFormatter numberFromString:self.amountField.text]);
    [self restoreBrightness];
}

- (IBAction) backup:(id)sender
{
    MYCBackupViewController* vc = [[MYCBackupViewController alloc] initWithNibName:nil bundle:nil];
    vc.completionBlock = ^(BOOL finished){
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    UINavigationController* navc = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:navc animated:YES completion:nil];
}


- (void)notifyKeyboardWillShow:(NSNotification *)notification
{
    CGRect windowKeyboardFrameEnd = [(NSValue *)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameEnd = [self.addressLabel.superview convertRect:windowKeyboardFrameEnd fromView:self.addressLabel.window];
    CGRect frame = self.addressLabel.frame;
    CGFloat bottom = CGRectGetMaxY(frame) - CGRectGetMinY(keyboardFrameEnd);
    
    if (bottom > 1)
    {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
        [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue]];
        [UIView setAnimationBeginsFromCurrentState:YES];
        
        self.QRCodeProportionalHeightConstraint.constant = - (bottom + 16);
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        
        [UIView commitAnimations];
    }
}

- (void)notifyKeyboardWillHide:(NSNotification *)notification
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    self.QRCodeProportionalHeightConstraint.constant = 0;
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    [UIView commitAnimations];
}




@end
