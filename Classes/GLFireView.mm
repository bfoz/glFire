/*

File: GLFireView.m
Abstract: This class wraps the CAEAGLLayer from CoreAnimation into a convenient
UIView subclass. The view content is basically an EAGL surface you render your
OpenGL scene into.  Note that setting the view non-opaque will only work if the
EAGL surface has an alpha channel.

Version: 2.1

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
("Apple") in consideration of your agreement to the following terms, and your
use, installation, modification or redistribution of this Apple software
constitutes acceptance of these terms.  If you do not agree with these terms,
please do not use, install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and subject
to these terms, Apple grants you a personal, non-exclusive license, under
Apple's copyrights in this original Apple software (the "Apple Software"), to
use, reproduce, modify and redistribute the Apple Software, with or without
modifications, in source and/or binary forms; provided that if you redistribute
the Apple Software in its entirety and without modifications, you must retain
this notice and the following text and disclaimers in all such redistributions
of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may be used
to endorse or promote products derived from the Apple Software without specific
prior written permission from Apple.  Except as expressly stated in this notice,
no other rights or licenses, express or implied, are granted by Apple herein,
including but not limited to any patent rights that may be infringed by your
derivative works or by other works in which the Apple Software may be
incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR
DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF
CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2009 Apple Inc. All Rights Reserved.

*/

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "GLFireView.h"

#include "ParticleFountain.h"

// CONSTANTS
#define kTeapotScale				3.0
#define	kAccelerationMagnitude			-0.15
#define	kFountainDiameter			0.01
#define	kFountainDirectionVariance		0.2
#define	kFountainRate				100
#define	kParticleLifespan			2
#define	kParticleLifespanVariance		0.1
#define	kParticleSpeed				0.15
#define	kParticleSpeedVariance			0.1
#if TARGET_IPHONE_SIMULATOR
#define	kAccelerationDirection			Vector3f(0,0,kAccelerationMagnitude)
#define	kFountainDirection			Vector3f(0,0,1)
#else
#define	kAccelerationDirection			Vector3f(0,kAccelerationMagnitude,0)
#define	kFountainDirection			Vector3f(0,1,0)
#endif

#define	kParticleTextureHeight			64
#define	kParticleTextureWidth			64

// MACROS
#define DEGREES_TO_RADIANS(__ANGLE__) ((__ANGLE__) / 180.0 * M_PI)

// A class extension to declare private methods
@interface GLFireView (_private)

- (BOOL)createFramebuffer;
- (void)destroyFramebuffer;
- (void)setupView;

@end

@implementation GLFireView

@synthesize animating;
@dynamic animationFrameInterval;
@synthesize accel;

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
	
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
	
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	
		if (!context || ![EAGLContext setCurrentContext:context]) {
			[self release];
			return nil;
		}
	
		animating = FALSE;
		displayLinkSupported = FALSE;
		animationFrameInterval = 1;
		displayLink = nil;
		animationTimer = nil;
	
		// A system version of 3.1 or greater is required to use CADisplayLink. The NSTimer
		// class is used as fallback when it isn't available.
		NSString *reqSysVer = @"3.1";
		NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
		if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
			displayLinkSupported = TRUE;
		
		accel = (UIAccelerationValue*)calloc(3, sizeof(UIAccelerationValue));

	fountain.position(Vector3f(0,0,0));
	fountain.acceleration(kAccelerationDirection);
	fountain.diameter(kFountainDiameter);
	fountain.direction(kFountainDirection);
	fountain.lifespan(kParticleLifespan);
	fountain.rate(kFountainRate);
	fountain.speed(kParticleSpeed);
	fountain.variance(kFountainDirectionVariance, kParticleLifespanVariance, kParticleSpeedVariance);
	fountain.start();

		[self setupView];
	}
	
	return self;
}
	
-(void)setupView
{
	const GLfloat			lightAmbient[] = {0.2, 0.2, 0.2, 1.0};
	const GLfloat			lightDiffuse[] = {1.0, 0.6, 0.0, 1.0};
	const GLfloat			matAmbient[] = {0.6, 0.6, 0.6, 1.0};
	const GLfloat			matDiffuse[] = {1.0, 1.0, 1.0, 1.0};	
	const GLfloat			matSpecular[] = {1.0, 1.0, 1.0, 1.0};
	const GLfloat			lightPosition[] = {0.0, 0.0, 1.0, 0.0}; 
	const GLfloat			lightShininess = 100.0,
							zNear = 0.1,
							zFar = 1000.0,
							fieldOfView = 60.0;
	GLfloat					size;
	
	//Configure OpenGL lighting
	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, matAmbient);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, matDiffuse);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, matSpecular);
	glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, lightShininess);
	glLightfv(GL_LIGHT0, GL_AMBIENT, lightAmbient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, lightDiffuse);
	glLightfv(GL_LIGHT0, GL_POSITION, lightPosition); 			
	glShadeModel(GL_SMOOTH);
	glEnable(GL_DEPTH_TEST);

    // Configure a texture to use for the point sprites
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_SRC_COLOR);
    glGenTextures(sizeof(textures)/sizeof(textures[0]), textures);
    glBindTexture(GL_TEXTURE_2D, textures[0]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    NSString *path = [[NSBundle mainBundle] pathForResource:@"particle" ofType:@"pvr4"];
    NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
    glCompressedTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,
			   kParticleTextureWidth, kParticleTextureHeight, 0,
			   (kParticleTextureWidth * kParticleTextureHeight) / 2,
			   [texData bytes]);

    // Enable point sprites
    glEnable(GL_POINT_SPRITE_OES);
    glTexEnvf(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
    glPointSize(10);

	//Configure OpenGL arrays
	glEnableClientState(GL_VERTEX_ARRAY);

	//Set the OpenGL projection matrix
	glMatrixMode(GL_PROJECTION);
	size = zNear * tanf(DEGREES_TO_RADIANS(fieldOfView) / 2.0);
	CGRect rect = self.bounds;
	glFrustumf(-size, size, -size / (rect.size.width / rect.size.height), size / (rect.size.width / rect.size.height), zNear, zFar);
	glViewport(0, 0, rect.size.width, rect.size.height);
	
	//Make the OpenGL modelview matrix the default
	glMatrixMode(GL_MODELVIEW);
}

// Updates the OpenGL view
- (void)drawView
{
	// Make sure that you are drawing to the current context
	[EAGLContext setCurrentContext:context];
		
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
	GLfloat matrix[4][4], length;
		
	//Make sure we have a big enough acceleration vector
	length = sqrtf(accel[0] * accel[0] + accel[1] * accel[1] + accel[2] * accel[2]);
		
	//Setup model view matrix
	glLoadIdentity();
	glTranslatef(0.0, -0.1, -1.0);
	glScalef(kTeapotScale, kTeapotScale, kTeapotScale);
		
	if(length >= 0.1)
	{
		//Clear matrix to be used to rotate from the current referential to one based on the gravity vector
		bzero(matrix, sizeof(matrix));
		matrix[3][3] = 1.0;
		
		//Setup first matrix column as gravity vector
		matrix[0][0] = accel[0] / length;
		matrix[0][1] = accel[1] / length;
		matrix[0][2] = accel[2] / length;
			
		//Setup second matrix column as an arbitrary vector in the plane perpendicular to the gravity vector {Gx, Gy, Gz} defined by by the equation "Gx * x + Gy * y + Gz * z = 0" in which we arbitrarily set x=0 and y=1
		matrix[1][0] = 0.0;
		matrix[1][1] = 1.0;
		matrix[1][2] = -accel[1] / accel[2];
		length = sqrtf(matrix[1][0] * matrix[1][0] + matrix[1][1] * matrix[1][1] + matrix[1][2] * matrix[1][2]);
		matrix[1][0] /= length;
		matrix[1][1] /= length;
		matrix[1][2] /= length;
		
		//Setup third matrix column as the cross product of the first two
		matrix[2][0] = matrix[0][1] * matrix[1][2] - matrix[0][2] * matrix[1][1];
		matrix[2][1] = matrix[1][0] * matrix[0][2] - matrix[1][2] * matrix[0][0];
		matrix[2][2] = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
		
		//Finally load matrix
		glMultMatrixf((GLfloat*)matrix);
		
		// Rotate a bit more so that its where we want it.
		glRotatef(90.0, 0.0, 0.0, 1.0);
	}
#if TARGET_IPHONE_SIMULATOR
    // The simulator doesn't emulate the accelerometers, so align the fountain
    //	vertically on the screen
	else
	    glRotatef(-90.0, 1.0, 0.0, 0.0);
#endif

    fountain.update([displayLink duration]);
    fountain.draw();

	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

// If our view is resized, we'll be asked to layout subviews.
// This is the perfect opportunity to also update the framebuffer so that it is
// the same size as our display area.
-(void)layoutSubviews
{
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];
	[self drawView];
}

- (BOOL)createFramebuffer
{
	// Generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	// For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
	glGenRenderbuffersOES(1, &depthRenderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);

	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	return YES;
}

// Clean up any buffers we have allocated.
- (void)destroyFramebuffer
{
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

- (NSInteger) animationFrameInterval
{
	return animationFrameInterval;
}

- (void) setAnimationFrameInterval:(NSInteger)frameInterval
{
	// Frame interval defines how many display frames must pass between each time the
	// display link fires. The display link will only fire 30 times a second when the
	// frame internal is two on a display that refreshes 60 times a second. The default
	// frame interval setting of one will fire 60 times a second when the display refreshes
	// at 60 times a second. A frame interval setting of less than one results in undefined
	// behavior.
	if (frameInterval >= 1)
	{
		animationFrameInterval = frameInterval;
		
		if (animating)
		{
			[self stopAnimation];
			[self startAnimation];
		}
	}
}

- (void) startAnimation
{
	if (!animating)
	{
		if (displayLinkSupported)
		{
			// CADisplayLink is API new to iPhone SDK 3.1. Compiling against earlier versions will result in a warning, but can be dismissed
			// if the system version runtime check for CADisplayLink exists in -initWithCoder:. The runtime check ensures this code will
			// not be called in system versions earlier than 3.1.
			
			displayLink = [NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(drawView)];
			[displayLink setFrameInterval:animationFrameInterval];
			[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		}
		else
			animationTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)((1.0 / 60.0) * animationFrameInterval) target:self selector:@selector(drawView) userInfo:nil repeats:TRUE];
		
		animating = TRUE;
	}
}

- (void)stopAnimation
{
	if (animating)
	{
		if (displayLinkSupported)
		{
			[displayLink invalidate];
			displayLink = nil;
		}
		else
		{
			[animationTimer invalidate];
			animationTimer = nil;
		}
		
		animating = FALSE;
	}
}

- (void)dealloc
{
	free(accel);
	
	if([EAGLContext currentContext] == context)
	{
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];
	[super dealloc];
}

@end
