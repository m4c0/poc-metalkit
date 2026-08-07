#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <MetalKit/MetalKit.h>

@interface POCAppDelegate : NSObject<NSApplicationDelegate>
@end
@implementation POCAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
  return YES;
}
@end

@interface POCViewController : NSViewController<MTKViewDelegate>
@property (nonatomic,strong) id<MTLCommandQueue> queue;
@property (nonatomic,strong) id<MTLRenderPipelineState> pipeline;
@end
@implementation POCViewController
- (void)drawInMTKView:(MTKView *)view {
  MTLRenderPassDescriptor * rpd = view.currentRenderPassDescriptor;
  if (rpd == nil) return;

  id<MTLCommandBuffer> cb = [self.queue commandBuffer];

  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:self.pipeline];
  [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  [enc endEncoding];

  [cb presentDrawable:view.currentDrawable];
  [cb commit];
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}
@end

static void run() {
  MTKView * view = [MTKView new];
  view.device = MTLCreateSystemDefaultDevice();
  view.clearColor = MTLClearColorMake(0.1, 0.2, 0.3, 1.0);

  POCViewController * vc = [POCViewController new];
  view.delegate = vc;
  vc.view = view;
  vc.queue = [view.device newCommandQueue];

  MTLCompileOptions * opts = [MTLCompileOptions new];
  NSError * err;
  NSString * src = @""
    "using namespace metal;"
    "vertex float4 vtx(uint vid [[vertex_id]]) {"
    "  return float4(vid & 1, (vid >> 1) & 1, 0, 1);"
    "}"
    "fragment float4 frg() {"
    "  return float4(0.3, 0.2, 0.1, 1);"
    "}";
  id <MTLLibrary> lib = [view.device newLibraryWithSource:src options:opts error:&err];
  if (err) {
    NSLog(@"Error compiling shader: %@", err);
    return;
  }

  MTLRenderPipelineDescriptor * pd = [MTLRenderPipelineDescriptor new];
  pd.vertexFunction = [lib newFunctionWithName:@"vtx"];
  pd.fragmentFunction = [lib newFunctionWithName:@"frg"];
  pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
  vc.pipeline = [view.device newRenderPipelineStateWithDescriptor:pd error:&err];
  if (err) {
    NSLog(@"Error creating pipeline: %@", err);
    return;
  }

  NSWindow * w = [NSWindow windowWithContentViewController:vc];
  w.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

  NSRect crect = NSMakeRect(0, 0, 800, 600);
  NSRect frect = [w frameRectForContentRect:crect];
  [w setFrame:frect display:YES];
  [w center];
  [w makeKeyAndOrderFront:w];

  NSMenu * menu = [NSMenu new];
  [menu       addItem:[[NSMenuItem alloc]
        initWithTitle:@"Quit App"
               action:@selector(terminate:)
        keyEquivalent:@"q"]];

  NSMenuItem * item = [NSMenuItem new];
  item.submenu = menu;

  NSMenu * bar = [NSMenu new];
  [bar addItem:item];

  NSApplication * a = [NSApplication sharedApplication];
  a.delegate = [POCAppDelegate new];
  a.mainMenu = bar;
  [a activateIgnoringOtherApps:YES];
  [a run];
}

int main() {
  @autoreleasepool {
    run();
  }
}
