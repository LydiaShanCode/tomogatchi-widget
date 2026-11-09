#!/usr/bin/env python3
"""Generate a deterministic, dependency-free Xcode project on Linux or macOS."""
from pathlib import Path
import hashlib, json
ROOT = Path(__file__).resolve().parent.parent
objects = {}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def q(s): return json.dumps(str(s))
def obj(key, isa, **fields):
    i=ident(key); objects[i]={'isa':isa,**fields};return i
def raw(s): return ('raw',s)
def fmt(v):
    if isinstance(v,tuple):return v[1]
    if isinstance(v,list):return '('+''.join(fmt(x)+',' for x in v)+')'
    if isinstance(v,dict):return '{'+''.join(str(k)+' = '+(str(x) if k == 'isa' else fmt(x))+'; ' for k,x in v.items())+'}'
    return q(v)
def ref(i):return raw(i)
files={}
def file(path,typ=None):
    if path not in files:
        ext=Path(path).suffix
        typ=typ or {'.swift':'sourcecode.swift','.plist':'text.plist.xml','.xcassets':'folder.assetcatalog','.xcconfig':'text.xcconfig','.xcprivacy':'text.xml'}.get(ext,'text')
        files[path]=obj('file:'+path,'PBXFileReference',lastKnownFileType=typ,path=path,sourceTree='<group>')
    return files[path]
def build(target,path,typ=None,settings=None):
    fields={'fileRef':ref(file(path,typ))}
    if settings:fields['settings']=settings
    return ref(obj('build:'+target+':'+path,'PBXBuildFile',**fields))
project=ident('project')
app=ident('target:FeedConnor');widget=ident('target:ConnorWidget');tests=ident('target:FeedConnorTests');uitests=ident('target:FeedConnorUITests')
products=[]
for name,ext in [('FeedConnor','app'),('ConnorWidget','appex'),('FeedConnorTests','xctest'),('FeedConnorUITests','xctest')]:
    products.append(obj('product:'+name,'PBXFileReference',explicitFileType={'app':'wrapper.application','appex':'wrapper.app-extension','xctest':'wrapper.cfbundle'}[ext],path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR',includeInIndex='0'))
common={'PRODUCT_NAME':'$(TARGET_NAME)','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'targeted','VERSIONING_SYSTEM':'apple-generic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
# Optional local overrides (ignored by Git) can supply team and bundle identifiers.
file('Config/Local.xcconfig')
def configs(key,extra):
    arr=[]
    for name in ['Debug','Release']:
        values={**common,**extra,'ONLY_ACTIVE_ARCH':'YES' if name=='Debug' else 'NO','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'}
        if name=='Debug':values['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        arr.append(ref(obj(key+name,'XCBuildConfiguration',name=name,buildSettings=values,baseConfigurationReference=ref(file('Config/Base.xcconfig')))))
    return obj(key+'configs','XCConfigurationList',buildConfigurations=arr,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
shared=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'Shared').glob('*.swift'))
for name,target,product,sources,resources,extra,ptype in [
 ('FeedConnor',app,products[0],shared+sorted(str(p.relative_to(ROOT)) for p in (ROOT/'App').glob('*.swift')),['Assets.xcassets','Resources/Character','Resources/Firebase','Resources/PrivacyInfo.xcprivacy'],{'PRODUCT_BUNDLE_IDENTIFIER':'$(APP_BUNDLE_ID)','INFOPLIST_FILE':'Config/App-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/App.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'},'application'),
 ('ConnorWidget',widget,products[1],shared+['Widget/ConnorWidget.swift'],['Resources/Character','Resources/PrivacyInfo.xcprivacy'],{'PRODUCT_BUNDLE_IDENTIFIER':'$(WIDGET_BUNDLE_ID)','INFOPLIST_FILE':'Config/Widget-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/Widget.entitlements','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES'},'app-extension'),
 ('FeedConnorTests',tests,products[2],['Shared/Models.swift','Shared/BodyAnimation.swift','Tests/StateTests.swift','Tests/AnimationTests.swift'],[],{'PRODUCT_BUNDLE_IDENTIFIER':'$(APP_BUNDLE_ID).tests','GENERATE_INFOPLIST_FILE':'YES','CODE_SIGNING_ALLOWED':'NO'},'bundle.unit-test'),
 ('FeedConnorUITests',uitests,products[3],['UITests/ScreenshotTests.swift'],[],{'PRODUCT_BUNDLE_IDENTIFIER':'$(APP_BUNDLE_ID).uitests','GENERATE_INFOPLIST_FILE':'YES','CODE_SIGNING_ALLOWED':'NO','TEST_TARGET_NAME':'FeedConnor'},'bundle.ui-testing')]:
    sourcePhase=obj(name+'sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=[build(name,p) for p in sources],runOnlyForDeploymentPostprocessing='0')
    # Folder references retain Character/ and Firebase/ subdirectories in the bundle.
    resourcePhase=obj(name+'resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=[build(name,p,'folder' if p in ['Resources/Character','Resources/Firebase'] else None) for p in resources],runOnlyForDeploymentPostprocessing='0')
    frameworks=[];packages=[]
    if name=='FeedConnor':
        for module in ['FirebaseAuth','FirebaseFirestore','FirebaseFunctions','FirebaseMessaging']:
            dep=obj('package:'+module,'XCSwiftPackageProductDependency',package=ref(ident('firebase')),productName=module)
            packages.append(ref(dep));frameworks.append(ref(obj('link:'+module,'PBXBuildFile',productRef=ref(dep))))
    frameworkPhase=obj(name+'frameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files=frameworks,runOnlyForDeploymentPostprocessing='0')
    phases=[ref(sourcePhase),ref(frameworkPhase),ref(resourcePhase)];dependencies=[]
    if name=='FeedConnor':
        proxy=obj('widgetProxy','PBXContainerItemProxy',containerPortal=ref(project),proxyType='1',remoteGlobalIDString=ref(widget),remoteInfo='ConnorWidget')
        dep=obj('widgetDependency','PBXTargetDependency',target=ref(widget),targetProxy=ref(proxy));dependencies.append(ref(dep))
        embedFile=obj('embedWidgetFile','PBXBuildFile',fileRef=ref(products[1]),settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
        embed=obj('embedWidget','PBXCopyFilesBuildPhase',buildActionMask='2147483647',dstPath='',dstSubfolderSpec='13',files=[ref(embedFile)],name='Embed App Extensions',runOnlyForDeploymentPostprocessing='0');phases.append(ref(embed))
    if name=='FeedConnorUITests':
        proxy=obj('appTestProxy','PBXContainerItemProxy',containerPortal=ref(project),proxyType='1',remoteGlobalIDString=ref(app),remoteInfo='FeedConnor')
        dependencies.append(ref(obj('appTestDependency','PBXTargetDependency',target=ref(app),targetProxy=ref(proxy))))
    objects[target]={'isa':'PBXNativeTarget','name':name,'productName':name,'productReference':ref(product),'productType':'com.apple.product-type.'+ptype,'buildConfigurationList':ref(configs(name,extra)),'buildPhases':phases,'buildRules':[],'dependencies':dependencies,'packageProductDependencies':packages}
productGroup=obj('products','PBXGroup',children=[ref(x) for x in products],name='Products',sourceTree='<group>')
rootGroup=obj('rootGroup','PBXGroup',children=[ref(x) for x in files.values()]+[ref(productGroup)],sourceTree='<group>')
obj('firebase','XCRemoteSwiftPackageReference',repositoryURL='https://github.com/firebase/firebase-ios-sdk.git',requirement={'kind':'exactVersion','version':'11.15.0'})
objects[project]={'isa':'PBXProject','attributes':{'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600'},'buildConfigurationList':ref(configs('project',{})),'compatibilityVersion':'Xcode 14.0','developmentRegion':'en','hasScannedForEncodings':'0','knownRegions':['en','Base'],'mainGroup':ref(rootGroup),'productRefGroup':ref(productGroup),'projectDirPath':'','projectRoot':'','targets':[ref(app),ref(widget),ref(tests),ref(uitests)],'packageReferences':[ref(ident('firebase'))]}
folder=ROOT/'FeedConnor.xcodeproj';folder.mkdir(exist_ok=True)
text='// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
for isa in sorted({x['isa'] for x in objects.values()}):
    text+='/* Begin '+isa+' section */\n'
    for i,data in sorted(objects.items()):
        if data['isa']==isa:text+=i+' = '+fmt(data)+';\n'
    text+='/* End '+isa+' section */\n'
text+='}; rootObject = '+project+'; }\n'
(folder/'project.pbxproj').write_text(text)
scheme=folder/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
def buildable(target,name,ext):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:FeedConnor.xcodeproj"/>'
(scheme/'FeedConnor.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable(app,'FeedConnor','app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildable(tests,'FeedConnorTests','xctest')}</TestableReference><TestableReference skipped="NO">{buildable(uitests,'FeedConnorUITests','xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(app,'FeedConnor','app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(app,'FeedConnor','app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated FeedConnor.xcodeproj')
