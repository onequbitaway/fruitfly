import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
let root=URL(fileURLWithPath:CommandLine.arguments[1])
for (name,seconds,frames) in [("fruitfly-desktop-full-map.mp4",12.0,360),("fruitfly-desktop-and-brain.mp4",20.0,600)] {
    let url=root.appendingPathComponent(name),asset=AVURLAsset(url:url)
    let track=asset.tracks(withMediaType:.video).first!
    precondition(abs(asset.duration.seconds-seconds)<0.001)
    precondition(track.naturalSize == CGSize(width:1280,height:800))
    precondition(abs(track.nominalFrameRate-30)<0.01)
    let format=track.formatDescriptions[0] as! CMFormatDescription
    precondition(CMFormatDescriptionGetMediaSubType(format)==kCMVideoCodecType_H264)
    let reader=try AVAssetReader(asset:asset)
    let output=AVAssetReaderTrackOutput(track:track,outputSettings:nil);reader.add(output);precondition(reader.startReading())
    var count=0
    while let sample=output.copyNextSampleBuffer() {count+=CMSampleBufferGetNumSamples(sample)}
    print("Read status",reader.status.rawValue,"samples",count,"expected",frames,"error",String(describing:reader.error));fflush(stdout)
    precondition(reader.status == .completed && count==frames)
    print(name,"verified",seconds,"seconds",count,"frames, H.264, 1280 × 800, 30 fps")
    let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true
    generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
    let image=try generator.copyCGImage(at:CMTime(value:75,timescale:30),actualTime:nil)
    let png=root.appendingPathComponent(name+".png")
    let target=CGImageDestinationCreateWithURL(png as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(target,image,nil);precondition(CGImageDestinationFinalize(target))
}
let source=CGImageSourceCreateWithURL(root.appendingPathComponent("fruitfly-desktop-full-map.gif") as CFURL,nil)!
precondition(CGImageSourceGetCount(source)==120)
for i in 0..<120 {
    let props=CGImageSourceCopyPropertiesAtIndex(source,i,nil)! as NSDictionary
    let gif=props[kCGImagePropertyGIFDictionary] as! NSDictionary
    precondition(abs((gif[kCGImagePropertyGIFDelayTime] as! Double)-0.1)<0.001)
    precondition((props[kCGImagePropertyPixelWidth] as! Int)==960 && (props[kCGImagePropertyPixelHeight] as! Int)==600)
}
print("GIF verified: 120 frames, 12 seconds, 960 × 600")
