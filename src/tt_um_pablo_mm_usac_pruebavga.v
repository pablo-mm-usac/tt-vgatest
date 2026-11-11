
/*
 * Tiny Tapeout VGA
 * Logo con velocidad ajustable y duplicacion por impacto
 * Maximo: 4 logotipos simultaneos
 */

`default_nettype none

`define COLOR_WHITE 3'd7

module tt_um_pablo_mm_usac_pruebavga (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  localparam LOGO_SIZE = 128;
  localparam DISPLAY_WIDTH = 640;
  localparam DISPLAY_HEIGHT = 480;

  // VGA
  wire hsync;
  wire vsync;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;

  // Controles
  wire cfg_tile  = ui_in[0];
  wire cfg_color = ui_in[1];
  wire cfg_duplicate = ui_in[7];

  // Velocidad: 1 a 32 pixeles por fotograma
  wire [9:0] speed =
      {5'b00000, ui_in[6:2]} + 10'd1;

  localparam [9:0] MAX_X =
      DISPLAY_WIDTH - LOGO_SIZE;
  localparam [9:0] MAX_Y =
      DISPLAY_HEIGHT - LOGO_SIZE;

  // Salidas VGA
  assign uo_out = {
      hsync, B[0], G[0], R[0],
      vsync, B[1], G[1], R[1]
  };

  assign uio_out = 8'b0;
  assign uio_oe = 8'b0;

  wire _unused_ok = &{ena, uio_in, vsync};

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // Hasta 4 logotipos
  reg [9:0] logo_left [0:3];
  reg [9:0] logo_top  [0:3];

  reg dir_x [0:3];
  reg dir_y [0:3];

  reg [2:0] color_index;
  reg [2:0] logo_count;

  reg [9:0] prev_y;

  // Cantidad visible
  wire [2:0] visible_count =
      cfg_duplicate ? logo_count : 3'd1;

  // Detectar impactos
  wire [3:0] hit_x;
  wire [3:0] hit_y;
  wire [3:0] hit_any;

  genvar k;

  generate
    for (k = 0; k < 4; k = k + 1) begin: HIT
      assign hit_x[k] =
          (dir_x[k] &&
           logo_left[k] >= MAX_X - speed) ||
          (!dir_x[k] &&
           logo_left[k] <= speed);

      assign hit_y[k] =
          (dir_y[k] &&
           logo_top[k] >= MAX_Y - speed) ||
          (!dir_y[k] &&
           logo_top[k] <= speed);

      assign hit_any[k] = hit_x[k] | hit_y[k];
    end
  endgenerate

  // Elegir un impacto para generar una copia
  reg spawn_valid;
  reg [1:0] spawn_idx;

  integer s;

  always @* begin
    spawn_valid = 1'b0;
    spawn_idx = 2'd0;

    for (s = 0; s < 4; s = s + 1) begin
      if (s < logo_count &&
          hit_any[s] &&
          !spawn_valid) begin
        spawn_valid = 1'b1;
        spawn_idx = s[1:0];
      end
    end
  end

  // Seleccion de logotipo para dibujar
  reg [6:0] rom_x;
  reg [6:0] rom_y;
  reg [2:0] selected_color;
  reg logo_pixels;

  integer j;

  always @* begin
    rom_x = pix_x[6:0];
    rom_y = pix_y[6:0];

    selected_color = color_index;
    logo_pixels = cfg_tile;

    if (!cfg_tile) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (j < visible_count &&
            pix_x >= logo_left[j] &&
            pix_x < logo_left[j] + LOGO_SIZE &&
            pix_y >= logo_top[j] &&
            pix_y < logo_top[j] + LOGO_SIZE) begin

          logo_pixels = 1'b1;

          rom_x = pix_x - logo_left[j];
          rom_y = pix_y - logo_top[j];

          selected_color =
              color_index + j[2:0];
        end
      end
    end
  end

  // Una sola ROM para ahorrar recursos
  wire pixel_value;

  bitmap_rom rom1 (
      .x(rom_x),
      .y(rom_y),
      .pixel(pixel_value)
  );

  wire [5:0] color;

  palette palette_inst (
      .color_index(
          cfg_color ? selected_color : `COLOR_WHITE
      ),
      .rrggbb(color)
  );

  // Generacion RGB
  always @(posedge clk) begin
    if (!rst_n) begin
      R <= 2'b00;
      G <= 2'b00;
      B <= 2'b00;
    end else begin
      R <= 2'b00;
      G <= 2'b00;
      B <= 2'b00;

      if (video_active && logo_pixels && pixel_value) begin
        R <= color[5:4];
        G <= color[3:2];
        B <= color[1:0];
      end
    end
  end

  // Movimiento y duplicacion
  integer i;

  always @(posedge clk) begin
    if (!rst_n) begin

      logo_count <= 3'd1;
      color_index <= 3'd0;
      prev_y <= 10'd0;

      for (i = 0; i < 4; i = i + 1) begin
        logo_left[i] <= 10'd200;
        logo_top[i] <= 10'd200;

        dir_x[i] <= 1'b1;
        dir_y[i] <= 1'b0;
      end

    end else begin

      prev_y <= pix_y;

      // Reiniciar copias al desactivar el modo
      if (!cfg_duplicate)
        logo_count <= 3'd1;

      // Actualizacion una vez por fotograma
      if (pix_y == 0 && prev_y != pix_y) begin

        for (i = 0; i < 4; i = i + 1) begin

          if (i < visible_count) begin

            // Movimiento horizontal
            if (dir_x[i]) begin

              if (hit_x[i]) begin
                logo_left[i] <= MAX_X;
                dir_x[i] <= 1'b0;
              end else begin
                logo_left[i] <= logo_left[i] + speed;
              end

            end else begin

              if (hit_x[i]) begin
                logo_left[i] <= 10'd0;
                dir_x[i] <= 1'b1;
              end else begin
                logo_left[i] <= logo_left[i] - speed;
              end

            end

            // Movimiento vertical
            if (dir_y[i]) begin

              if (hit_y[i]) begin
                logo_top[i] <= MAX_Y;
                dir_y[i] <= 1'b0;
              end else begin
                logo_top[i] <= logo_top[i] + speed;
              end

            end else begin

              if (hit_y[i]) begin
                logo_top[i] <= 10'd0;
                dir_y[i] <= 1'b1;
              end else begin
                logo_top[i] <= logo_top[i] - speed;
              end

            end

          end
        end

        // Cambiar color cuando hay impactos
        if ((visible_count > 0 && hit_any[0]) ||
            (visible_count > 1 && hit_any[1]) ||
            (visible_count > 2 && hit_any[2]) ||
            (visible_count > 3 && hit_any[3])) begin

          color_index <= color_index + 3'd1;

        end

        // Crear una nueva copia al impactar
        if (cfg_duplicate &&
            logo_count < 3'd4 &&
            spawn_valid) begin

          logo_left[logo_count] <=
              logo_left[spawn_idx];

          logo_top[logo_count] <=
              logo_top[spawn_idx];

          // Direcciones opuestas
          dir_x[logo_count] <=
              ~dir_x[spawn_idx];

          dir_y[logo_count] <=
              ~dir_y[spawn_idx];

          logo_count <= logo_count + 3'd1;

        end

      end
    end
  end

endmodule

`default_nettype wire
