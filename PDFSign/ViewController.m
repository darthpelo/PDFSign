//
//  ViewController.m
//  PDFSign
//
//  Created by Alessio Roberto on 16/04/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "SmoothLineView.h"
//#import "SmoothLineView_new.h"

@interface ViewController () {
    CGPDFPageRef page;
	CGPDFDocumentRef pdf;
    CGRect pageRect;
    // current pdf zoom scale
	CGFloat pdfScale;
    // A low res image of the PDF page that is displayed until the TiledPDFView
	// renders its content.
	UIImageView *backgroundImageView;
}

- (void)sendPDF;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Invia" style:UIBarButtonItemStyleBordered target:self action:@selector(sendPDF)];
    
    // Open the PDF document
    NSURL *pdfURL = [[NSBundle mainBundle] URLForResource:@"C_21.pdf" withExtension:nil];
    pdf = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfURL);
    
    // Get the PDF Page that we will be drawing
    page = CGPDFDocumentGetPage(pdf, 1);
    CGPDFPageRetain(page);
    
    // determine the size of the PDF page
    pageRect = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    pdfScale = self.view.frame.size.width/pageRect.size.width;
    pageRect.size = CGSizeMake(pageRect.size.width*pdfScale, pageRect.size.height*pdfScale);
    
    
    // Create a low res image representation of the PDF page to display before the TiledPDFView
    // renders its content.
    UIGraphicsBeginImageContext(pageRect.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // First fill the background with white.
    CGContextSetRGBFillColor(context, 1.0,1.0,1.0,1.0);
    CGContextFillRect(context,pageRect);
    
    CGContextSaveGState(context);
    // Flip the context so that the PDF page is rendered
    // right side up.
    CGContextTranslateCTM(context, 0.0, pageRect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // Scale the context so that the PDF page is rendered 
    // at the correct size for the zoom level.
    CGContextScaleCTM(context, pdfScale,pdfScale);	
    CGContextDrawPDFPage(context, page);
    CGContextRestoreGState(context);
    
    UIImage *backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    [self.view addSubview:[[SmoothLineView alloc] initWithFrame:self.view.bounds andImage:backgroundImage]];
//    [self.view addSubview:[[SmoothLineView_new alloc] initWithFrame:self.view.bounds andImage:backgroundImage]];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

- (UIImage*)screenshot 
{
    // Create a graphics context with the target size
    // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
    // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
    // CGSize imageSize = [[UIScreen mainScreen] bounds].size;
    CGSize imageSize = pageRect.size;
    if (NULL != UIGraphicsBeginImageContextWithOptions)
        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    else
        UIGraphicsBeginImageContext(imageSize);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) 
    {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen])
        {
            // -renderInContext: renders in the coordinate space of the layer,
            // so we must first apply the layer's geometry to the graphics context
            CGContextSaveGState(context);
            // Center the context around the window's anchor point
            CGContextTranslateCTM(context, [window center].x, [window center].y - 64);
            // Apply the window's transform about the anchor point
            CGContextConcatCTM(context, [window transform]);
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context,
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);
            
            // Render the layer hierarchy to the current context
            [[window layer] renderInContext:context];
            
            // Restore the context
            CGContextRestoreGState(context);
        }
    }
    
    // Retrieve the screenshot image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

- (void) drawImage:(UIImage *)img
{
    [img drawInRect:CGRectMake(0,0, pageRect.size.width, pageRect.size.height)];
}

- (void) generatePdfWithFilePath: (NSString *)thefilePath andImage:(UIImage *)image
{
    UIGraphicsBeginPDFContextToFile(thefilePath, CGRectZero, nil);
    
    BOOL done = NO;
    do 
    {
        //Start a new page.
        UIGraphicsBeginPDFPageWithInfo(CGRectMake(0, 0, pageRect.size.width, pageRect.size.height), nil);
        
        //Draw an image
        [self drawImage:image];
        done = YES;
    } 
    while (!done);
    
    // Close the PDF context and write the contents out.
    UIGraphicsEndPDFContext();
}

- (void)sendPDF
{
    UIImage *finalImage = [self screenshot];
    NSString *fileName = @"Demo.pdf";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *pdfFilePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    [self generatePdfWithFilePath:pdfFilePath andImage:finalImage];
    
    if ([MFMailComposeViewController canSendMail]) {
        // create mail composer object
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        
        // make this view the delegate
        mailer.mailComposeDelegate = self;
        
        //Add attachmnet
        NSData *myData = [NSData dataWithContentsOfFile:pdfFilePath];
        [mailer addAttachmentData:myData mimeType:@"application/pdf" fileName:fileName];
        [self presentModalViewController:mailer animated:YES];       
    }
    else {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"ImpossibileInviare" message:@"Mail Non Configurata"
                                                        delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }

}

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissModalViewControllerAnimated:YES];
}

@end
