/**
 * 
 * PixelFlow | Copyright (C) 2016 Thomas Diewald - http://thomasdiewald.com
 * 
 * A Processing/Java library for high performance GPU-Computing (GLSL).
 * MIT License: https://opensource.org/licenses/MIT
 * 
 */




import com.thomasdiewald.pixelflow.java.DwPixelFlow;
import com.thomasdiewald.pixelflow.java.dwgl.DwGLSLProgram;
import com.thomasdiewald.pixelflow.java.fluid.DwFluid2D;
import com.thomasdiewald.pixelflow.java.fluid.DwFluidParticleSystem2D;

import controlP5.Accordion;
import controlP5.ControlP5;
import controlP5.Group;
import controlP5.RadioButton;
import controlP5.Toggle;
import processing.core.*;
import processing.opengl.PGraphics2D;
// tcp
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.*;
import java.util.Base64;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
// udp
import hypermedia.net.*;
UDP udp;// udp 服务端
JSONObject json;

float hx,hy,phx,phy;

boolean isLoading = false;
String statusMsg = "";

// Fluid_LiquidPainting loads an image and uses it as a density source by
// copying each pixels rgb data to the density map of the fluid solver.
//
// addDensityTexture()
// The key to control the result is in the GLSL shader "data/addDensity.frag".
// Here the new data (image pixels) are added to the existing density.
//
// controls:
//
// LMB: add Velocity
// MMB: add Density
// RMB: add Temperature


private class MyFluidData implements DwFluid2D.FluidData{
  
  @Override
  // this is called during the fluid-simulation update step.
  public void update(DwFluid2D fluid) {
  
    float px, py, vx, vy, radius, vscale;

    //boolean mouse_input = !cp5.isMouseOver() && mousePressed;
    // mouse_input
    if(true ){
      
      vscale = 15;
      //px     = mouseX;
      //py     = height-mouseY;
      //vx     = (mouseX - pmouseX) * +vscale;
      //vy     = (mouseY - pmouseY) * -vscale;
      px     = hx*width;
      py     = height*(1.0-hy);
      vx     = width*(hx - phx) * +vscale;
      vy     = height*(hy - phy) * -vscale;
      //if(mouseButton == LEFT){
      //  radius = 20;
      //  fluid.addVelocity(px, py, radius, vx, vy);
      //}
      //if(mouseButton == CENTER){
      //  radius = 50;
      //  fluid.addDensity (px, py, radius, 1.0f, 0.0f, 0.40f, 1f, 1);
      //}
      //if(mouseButton == RIGHT){
      //  radius = 15;
      //  fluid.addTemperature(px, py, radius, 15f);
      //}
      radius = 20;
        fluid.addVelocity(px, py, radius, vx, vy);
    }

    // use the text as input for density
    float mix = fluid.simulation_step == 0 ? 1.0f : 0.01f;
    addDensityTexture(fluid, pg_image, mix);
  }
  
  // custom shader, to add density from a texture (PGraphics2D) to the fluid.
  public void addDensityTexture(DwFluid2D fluid, PGraphics2D pg, float mix){
    int[] pg_tex_handle = new int[1];
//      pg_tex_handle[0] = pg.getTexture().glName;
    context.begin();
    context.getGLTextureHandle(pg, pg_tex_handle);
    context.beginDraw(fluid.tex_density.dst);
    DwGLSLProgram shader = context.createShader(this, "data/addDensity.frag");
    shader.begin();
    shader.uniform2f     ("wh"        , fluid.fluid_w, fluid.fluid_h);                                                                   
    shader.uniform1i     ("blend_mode", 6);   
    shader.uniform1f     ("mix_value" , mix);     
    shader.uniform1f     ("multiplier", 1);     
    shader.uniformTexture("tex_ext"   , pg_tex_handle[0]);
    shader.uniformTexture("tex_src"   , fluid.tex_density.src);
    shader.drawFullScreenQuad();
    shader.end();
    context.endDraw();
    context.end("app.addDensityTexture");
    fluid.tex_density.swap();
  }
 
}

int viewport_w = 1280;
int viewport_h = 720;
int viewport_x = 230;
int viewport_y = 0;

int gui_w = 200;
int gui_x = 0;
int gui_y = 0;

int fluidgrid_scale = 1;

DwPixelFlow context;
DwFluid2D fluid;

MyFluidData cb_fluid_data;
DwFluidParticleSystem2D particle_system;

PGraphics2D pg_fluid;       // render target
PGraphics2D pg_image;       // texture-buffer, for adding fluid data

PImage image;

// some state variables for the GUI/display
int     BACKGROUND_COLOR           = 0;
boolean UPDATE_FLUID               = true;
boolean DISPLAY_FLUID_TEXTURES     = true;
boolean DISPLAY_FLUID_VECTORS      = false;
int     DISPLAY_fluid_texture_mode = 0;
boolean DISPLAY_PARTICLES          = false;

boolean isReady = false;
public void settings() {
  size(viewport_w, viewport_h, P2D);
  smooth(4);
}

public void setup() {
    
    surface.setLocation(viewport_x, viewport_y);
    
    // main library context
    context = new DwPixelFlow(this);
    context.print();
    context.printGL();
    
    // fluid simulation
    fluid = new DwFluid2D(context, viewport_w, viewport_h, fluidgrid_scale);
    
    // some fluid parameters
    fluid.param.dissipation_density     = 1.00f;
    fluid.param.dissipation_velocity    = 0.95f;
    fluid.param.dissipation_temperature = 0.70f;
    fluid.param.vorticity               = 0.50f;
    
    // interface for adding data to the fluid simulation
    cb_fluid_data = new MyFluidData();
    fluid.addCallback_FluiData(cb_fluid_data);
    
    // image, used for density
    // test.jpg faceTest.jpg
    // 1.
     //image = loadImage("test.jpg");
    // 2.
    //String url = "http://192.168.110.69:8080/directlink/1/books-2869_1280.jpg";
    //// 只要发出请求，程序立刻往下走，不会卡顿
    //image = requestImage(url);
    // 3.
    // 启动一个新线程来处理网络请求，避免卡死主界面
    thread("fetchImageTask");
    
    // udp 服务端 ip 和端口号
    udp = new UDP( this, 9000 );
    udp.listen( true );

    // fluid render target
    pg_fluid = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
    pg_fluid.smooth(4);
    
    // particles
    particle_system = new DwFluidParticleSystem2D();
    particle_system.resize(context, viewport_w/3, viewport_h/3);
    
    // image/buffer that will be used as density input
    //pg_image = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
    //pg_image.noSmooth();
    //pg_image.beginDraw();
    //pg_image.clear();
    //pg_image.translate(width/2, height/2);
    //pg_image.scale(viewport_h / (float)image.height);
    //pg_image.imageMode(CENTER);
    //pg_image.image(image, 0, 0);
    //pg_image.endDraw();

    createGUI();

    background(0);
    frameRate(60);
    
    hx=hy=phx=phy=0;
}
  
  
  

public void draw() {
    
    if(image != null && image.width > 0){
      pg_image = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
      pg_image.noSmooth();
      pg_image.beginDraw();
      pg_image.clear();
      pg_image.translate(width/2, height/2);
      pg_image.scale(viewport_h / (float)image.height);
      pg_image.imageMode(CENTER);
      pg_image.image(image, 0, 0);
      pg_image.endDraw();
      isReady = true;
    }else{
      background(0);
      textSize(64);
      String loadStr = "Loading ";
      for(int i=0; i<(frameCount / 60)%6;i++){
        loadStr += ".";
      }
      text(loadStr, width/2-128, height/2);
    }
    
    if(!isReady) return;
   
    if(UPDATE_FLUID){
      fluid.update();
      particle_system.update(fluid);
    }

    pg_fluid.beginDraw();
    pg_fluid.background(BACKGROUND_COLOR);
    pg_fluid.endDraw();
    
    if(DISPLAY_FLUID_TEXTURES){
      fluid.renderFluidTextures(pg_fluid, DISPLAY_fluid_texture_mode);
    }
    
    if(DISPLAY_FLUID_VECTORS){
      fluid.renderFluidVectors(pg_fluid, 10);
    }
    
    if(DISPLAY_PARTICLES){
      particle_system.render(pg_fluid, null, 0);
    }
    
    // display
    image(pg_fluid, 0, 0);
 
    // info
    String txt_fps = String.format(getClass().getName()+ "   [size %d/%d]   [frame %d]   [fps %6.2f]", fluid.fluid_w, fluid.fluid_h, fluid.simulation_step, frameRate);
    surface.setTitle(txt_fps);
    
    if(json != null){
      if(json.getFloat("confidence")>0.75f){
        fill(0,255,0);
      }else if(json.getFloat("confidence")>0){
        fill(255,165,0);
      }else{
        fill(200);
      }
      textSize(64);
      textAlign(CENTER);
      text(json.getString("gesture"),144,height/2);
    }
  }
  
// ==========================================
//  后台线程任务 (先 POST，再 RequestImage)
// ==========================================
void fetchImageTask() {
  isLoading = true;
  image = null; // 清空上一张图
  
  // 1. 定义 API 地址和要发送的 JSON
  String apiUrl = "http://127.0.0.1:7860/sdapi/v1/txt2img"; 
  //String apiUrl = "http://127.0.0.1:5000/generate"; 
  JSONObject jsonPayload = new JSONObject();
  jsonPayload.setString("prompt","songdai,  tree,  mountain,  rock,  plum tree, river, water, waterfall, forest, architecture, man, woman, sitting, standing, multi-people, guqin");
  jsonPayload.setInt("steps",20);
  println("Step 1: Sending POST request...");
  
  // 2. 发送 POST 并获取响应文本
  String response = sendPostRequest(apiUrl, jsonPayload.toString());
  
  if (response != null) {
    println("Response received: " + response);
    
    try {
      // 3. 解析 JSON 响应
      JSONObject json = parseJSONObject(response);
      
      // 假设服务器返回的 JSON 结构是: { "img_url": "http://..." }
      JSONArray imgArray = json.getJSONArray("images");
      String imgData = imgArray.toStringArray()[0];
      
      // 4. 异步加载图片
      // 注意：requestImage 本身就是异步的，但在 thread 里调用也没问题
      image = base64ToPImage(imgData);
      
    } catch (Exception e) {
      println("JSON Parsing Error: " + e.getMessage());
      statusMsg = "Error: Invalid JSON response";
    }
  } else {
    statusMsg = "Error: API Request Failed";
  }
  delay(100); 
  isLoading = false; 
}


// ==========================================
//  底层 HTTP POST 工具函数 (Java 原生实现)
// ==========================================
String sendPostRequest(String urlString, String jsonInputString) {
  HttpURLConnection con = null;
  try {
    URL url = new URL(urlString);
    con = (HttpURLConnection) url.openConnection();
    
    // 设置请求头
    con.setRequestMethod("POST");
    con.setRequestProperty("Content-Type", "application/json; utf-8");
    con.setRequestProperty("Accept", "application/json");
    con.setDoOutput(true); // 允许发送 Body 数据
    con.setConnectTimeout(50*1000); // 连接超时 50秒
    con.setReadTimeout(100*1000);   // 读取超时 100秒

    // 写入 Body 数据
    try (OutputStream os = con.getOutputStream()) {
      byte[] input = jsonInputString.getBytes("utf-8");
      os.write(input, 0, input.length);
    }

    // 读取响应状态
    int code = con.getResponseCode();
    println("HTTP Status: " + code);

    // 读取响应内容
    InputStream is = (code >= 200 && code < 300) ? con.getInputStream() : con.getErrorStream();
    BufferedReader br = new BufferedReader(new InputStreamReader(is, "utf-8"));
    StringBuilder response = new StringBuilder();
    String responseLine = null;
    while ((responseLine = br.readLine()) != null) {
      response.append(responseLine.trim());
    }
    return response.toString();

  } catch (Exception e) {
    e.printStackTrace();
    return null;
  } finally {
    if (con != null) {
      con.disconnect();
    }
  }
}

// udp 监听
void receive( byte[] data, String ip, int port ) {
  String message = new String( data );
  json = parseJSONObject(message);
  //println(json.getJSONObject("center"));
  phx = hx;
  phy = hy;
  hx=json.getJSONObject("center").getFloat("x");
  hy=json.getJSONObject("center").getFloat("y");
}

// ==================================================
// 核心工具函数：将 Base64 字符串转换为 Processing PImage
// ==================================================
PImage base64ToPImage(String b64Data) {
  BufferedImage bimg = null;
  byte[] decodedBytes = null;
  
  try {
    // --- 步骤 0: 清理数据头 ---
    // 很多 Web API 返回的 Base64 带有前缀，例如: "data:image/png;base64,iVBORw0KGgoAAAAN..."
    // Java 的解码器无法识别这个前缀，必须去掉，只保留逗号后面的纯 Base64 部分。
    String pureBase64 = "";
    if (b64Data.contains(",")) {
      pureBase64 = b64Data.split(",")[1];
    } else {
      pureBase64 = b64Data;
    }
    
    // --- 步骤 1: 解码 (String -> byte[]) ---
    // 使用 Java 8 的标准 Base64 解码器
    decodedBytes = Base64.getDecoder().decode(pureBase64);
    
    // --- 步骤 2: 转换为 Java 图像 (byte[] -> BufferedImage) ---
    // ByteArrayInputStream 就像一个管道，把内存里的字节流喂给 ImageIO
    ByteArrayInputStream bis = new ByteArrayInputStream(decodedBytes);
    // ImageIO.read 会自动识别字节流是 JPG 还是 PNG，并解析它
    bimg = ImageIO.read(bis);
    bis.close();
    
    if (bimg == null) {
       println("Error: The Base64 string did not contain valid image data.");
       return null;
    }

  } catch (IllegalArgumentException e) {
    println("Error: Invalid Base64 string format.");
    e.printStackTrace();
    return null;
  } catch (IOException e) {
    println("Error: Could not read image data.");
    e.printStackTrace();
    return null;
  } catch (Exception e) {
     println("Unknown Error during decoding: " + e.getMessage());
     return null;
  }
  
  // --- 步骤 3: 桥接到 Processing (BufferedImage -> PImage) ---
  // 创建一个新的 PImage，尺寸与解析出的 Java 图像一致
  PImage pimg = new PImage(bimg.getWidth(), bimg.getHeight(), ARGB);
  
  // 将 BufferedImage 的像素数据一次性复制到 PImage 中
  // 这是一个高效的操作，比一个一个像素循环设置要快得多
  bimg.getRGB(0, 0, pimg.width, pimg.height, pimg.pixels, 0, pimg.width);
  
  // 告诉 Processing 像素数组已经更新，准备渲染
  pimg.updatePixels();
  
  return pimg;
}

public void fluid_resizeUp(){
  fluid.resize(width, height, fluidgrid_scale = max(1, --fluidgrid_scale));
}
public void fluid_resizeDown(){
  fluid.resize(width, height, ++fluidgrid_scale);
}
public void fluid_reset(){
  fluid.reset();
}
public void fluid_togglePause(){
  UPDATE_FLUID = !UPDATE_FLUID;
}
public void fluid_displayMode(int val){
  DISPLAY_fluid_texture_mode = val;
  DISPLAY_FLUID_TEXTURES = DISPLAY_fluid_texture_mode != -1;
}
public void fluid_displayVelocityVectors(int val){
  DISPLAY_FLUID_VECTORS = val != -1;
}

public void fluid_displayParticles(int val){
  DISPLAY_PARTICLES = val != -1;
}

public void keyReleased(){
  if(key == 'p') fluid_togglePause(); // pause / unpause simulation
  if(key == '+') fluid_resizeUp();    // increase fluid-grid resolution
  if(key == '-') fluid_resizeDown();  // decrease fluid-grid resolution
  if(key == 'r') fluid_reset();       // restart simulation
  
  if(key == '1') DISPLAY_fluid_texture_mode = 0; // density
  if(key == '2') DISPLAY_fluid_texture_mode = 1; // temperature
  if(key == '3') DISPLAY_fluid_texture_mode = 2; // pressure
  if(key == '4') DISPLAY_fluid_texture_mode = 3; // velocity
  
  if(key == 'q') DISPLAY_FLUID_TEXTURES = !DISPLAY_FLUID_TEXTURES;
  if(key == 'w') DISPLAY_FLUID_VECTORS  = !DISPLAY_FLUID_VECTORS;
}
 


ControlP5 cp5;

public void createGUI(){
  cp5 = new ControlP5(this);
  
  int sx, sy, px, py, oy;
  
  sx = 100; sy = 14; oy = (int)(sy*1.5f);
  

  ////////////////////////////////////////////////////////////////////////////
  // GUI - FLUID
  ////////////////////////////////////////////////////////////////////////////
  Group group_fluid = cp5.addGroup("fluid");
  {
    group_fluid.setHeight(20).setSize(gui_w, 300)
    .setBackgroundColor(color(16, 180)).setColorBackground(color(16, 180));
    group_fluid.getCaptionLabel().align(CENTER, CENTER);
    
    px = 10; py = 15;
    
    cp5.addButton("reset").setGroup(group_fluid).plugTo(this, "fluid_reset"     ).setSize(80, 18).setPosition(px    , py);
    cp5.addButton("+"    ).setGroup(group_fluid).plugTo(this, "fluid_resizeUp"  ).setSize(39, 18).setPosition(px+=82, py);
    cp5.addButton("-"    ).setGroup(group_fluid).plugTo(this, "fluid_resizeDown").setSize(39, 18).setPosition(px+=41, py);
    
    px = 10;
   
    cp5.addSlider("velocity").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=(int)(oy*1.5f))
        .setRange(0, 1).setValue(fluid.param.dissipation_velocity).plugTo(fluid.param, "dissipation_velocity");
    
    cp5.addSlider("density").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
        .setRange(0, 1).setValue(fluid.param.dissipation_density).plugTo(fluid.param, "dissipation_density");
    
    cp5.addSlider("temperature").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
        .setRange(0, 1).setValue(fluid.param.dissipation_temperature).plugTo(fluid.param, "dissipation_temperature");
    
    cp5.addSlider("vorticity").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
        .setRange(0, 1).setValue(fluid.param.vorticity).plugTo(fluid.param, "vorticity");
        
    cp5.addSlider("iterations").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
        .setRange(0, 80).setValue(fluid.param.num_jacobi_projection).plugTo(fluid.param, "num_jacobi_projection");
          
    cp5.addSlider("timestep").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
        .setRange(0, 1).setValue(fluid.param.timestep).plugTo(fluid.param, "timestep");
        
    cp5.addSlider("gridscale").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
        .setRange(0, 50).setValue(fluid.param.gridscale).plugTo(fluid.param, "gridscale");
    
    RadioButton rb_setFluid_DisplayMode = cp5.addRadio("fluid_displayMode").setGroup(group_fluid).setSize(80,18).setPosition(px, py+=(int)(oy*1.5f))
        .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(2)
        .addItem("Density"    ,0)
        .addItem("Temperature",1)
        .addItem("Pressure"   ,2)
        .addItem("Velocity"   ,3)
        .activate(DISPLAY_fluid_texture_mode);
    for(Toggle toggle : rb_setFluid_DisplayMode.getItems()) toggle.getCaptionLabel().alignX(CENTER);
    
    cp5.addRadio("fluid_displayVelocityVectors").setGroup(group_fluid).setSize(18,18).setPosition(px, py+=(int)(oy*2.5f))
        .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(1)
        .addItem("Velocity Vectors", 0)
        .activate(DISPLAY_FLUID_VECTORS ? 0 : 2);
  }
  
  
  ////////////////////////////////////////////////////////////////////////////
  // GUI - DISPLAY
  ////////////////////////////////////////////////////////////////////////////
  Group group_display = cp5.addGroup("display");
  {
    group_display.setHeight(20).setSize(gui_w, 50)
    .setBackgroundColor(color(16, 180)).setColorBackground(color(16, 180));
    group_display.getCaptionLabel().align(CENTER, CENTER);
    
    px = 10; py = 15;
    
    cp5.addSlider("BACKGROUND").setGroup(group_display).setSize(sx,sy).setPosition(px, py)
        .setRange(0, 255).setValue(BACKGROUND_COLOR).plugTo(this, "BACKGROUND_COLOR");
    
    cp5.addRadio("fluid_displayParticles").setGroup(group_display).setSize(18,18).setPosition(px, py+=(int)(oy*1.5f))
        .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(1)
        .addItem("display particles", 0)
        .activate(DISPLAY_PARTICLES ? 0 : 2);
  }
  
  
  ////////////////////////////////////////////////////////////////////////////
  // GUI - ACCORDION
  ////////////////////////////////////////////////////////////////////////////
  cp5.addAccordion("acc").setPosition(gui_x, gui_y).setWidth(gui_w).setSize(gui_w, height)
    .setCollapseMode(Accordion.MULTI)
    .addItem(group_fluid)
    .addItem(group_display)
    .open(4);
}
  
