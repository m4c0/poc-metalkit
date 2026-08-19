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
@property (nonatomic,strong) id<MTLTexture> texture;
@end
@implementation POCViewController
- (void)drawInMTKView:(MTKView *)view {
  MTLRenderPassDescriptor * rpd = view.currentRenderPassDescriptor;
  if (rpd == nil) return;

  id<MTLCommandBuffer> cb = [self.queue commandBuffer];

  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:self.pipeline];
  [enc setFragmentTexture:self.texture atIndex:0];
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
    "constexpr sampler smp(mag_filter::linear, min_filter::linear); "
    "fragment float4 frg(texture2d<half> txt [[texture(0)]]) {"
    "  return float4(txt.sample(smp, float2(0.5, 0.5)));"
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

  MTLTextureDescriptor * td = [MTLTextureDescriptor new];
  td.pixelFormat = MTLPixelFormatRGBA8Unorm;
  td.width       = 16;
  td.height      = 16;
  vc.texture = [view.device newTextureWithDescriptor:td];

  uint32_t bytes[16 * 16];
  for (int i = 0; i < 16 * 16; i++) bytes[i] = 0xff5555ff;

  MTLRegion r = { {0,0,0}, {16,16,1} };
  [vc.texture replaceRegion:r mipmapLevel:0 withBytes:bytes bytesPerRow:16*4];

  NSWindow * w = [NSWindow windowWithContentViewController:vc];
  w.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

  NSRect crect = NSMakeRect(0, 0, 600, 600);
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
